local HostInfo = require('./base').HostInfo
local Apache2 = require('./apache2')
local walk = require('luvit-walk').readdirRecursive
local async = require('async')
local misc = require('./misc')
local safeMerge = misc.safeMerge
local read = misc.read
local path = require('path')
local Transform = require('stream').Transform
local Nginx = require('./nginx_config')
------------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

local VersionReader = Reader:extend()
function VersionReader:_transform(line, cb)
  if line:find('wp_version% %=') then
    self:push(line:match("wp_version% %=% %'(%S+)'"))
  end
  cb()
end

local PluginsReader = Reader:extend()
function PluginsReader:_transform(line, cb)
  if line:find('Version%:') then
    self:push({version = line:match(':%s(%S+)')})
  elseif line:find('Plugin%sName%:') then
    self:push({name = line:match(':%s(%S+)')})
  end
  cb()
end

------------------------------------------------------------------------------------------------------------------------
--[[ Wordpress ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local function getDocroots(cb)
    local docroots, errs = {}, {}
    local function template(Klass, cb)
      local klass = Klass.Info:new()
      klass:run(function(err)
        if err then return cb() end
        local out = klass:serialize().metrics
        if out.vhosts then
          cb(nil, out.vhosts)
        else
          cb('No vhosts found')
        end
      end)
    end

    async.parallel({
      function(cb)
        template(Apache2, function(err, vhosts)
          if err then
            safeMerge(errs, err)
            return cb()
          end

          table.foreach(vhosts, function(_, vhost)
            table.foreach(vhost, function(_, site)
              docroots[site['vhost']] = site['docroot']
            end)
          end)

          cb()
        end)
      end,
      function(cb)
        template(Nginx, function(err, vhosts)
          if err then
            safeMerge(errs, err)
            return cb()
          end

          table.foreach(vhosts, function(_, vhost)
            docroots[vhost['domain']] = vhost['docroot']
          end)

          cb()
        end)
      end
    }, function()
      if not docroots or not next(docroots) then
        cb(errs)
      else
        cb(nil, docroots)
      end
    end)
  end


  local function getVersion(dir, cb)
    local out, errs = {}, {}
    local version_fle = path.join(dir, 'wp-includes', 'version.php')
    local readStream = read(version_fle)
    -- Handle file not found errors
    readStream:on('error', function(err)
      safeMerge(errs, err)
      cb(errs)
    end)
    local reader = VersionReader:new()
    readStream:pipe(reader)
    reader:on('data', function(data) safeMerge(out, data) end)
    reader:once('end', function()
      if errs and not out or not next(out) then
        cb(errs)
      else
        cb(nil, out)
      end
    end)
  end

  local function getPlugins(dir, callback)
    local plugins, errs = {}, {}
    walk(path.join(dir, 'wp-content', 'plugins'), function(err, filesList)
      if err or not filesList or not next(filesList) then
        safeMerge(errs, err)
        return callback(errs)
      end

      async.forEachLimit(filesList, 5, function(filepath, cb)
        local version, name
        local readStream = read(filepath)
        local reader = PluginsReader:new()
        readStream:on('error', function(err)
          safeMerge(errs, err)
          return cb()
        end)

        readStream:pipe(reader)
        reader:on('data', function(data)
          if data.version then
            version = data.version
          elseif data.name then
            name = data.name
          end
        end)
        reader:once('end', function()
          if name and version then
            table.insert(plugins, {
              name = name,
              version = version
            })
          end
          cb()
        end)
      end, function()
        if errs and not plugins or not next(plugins) then
          callback(errs)
        else
          callback(nil, plugins)
        end
      end)
    end)
  end

  local function findWordpress(docroots, cb)
    local found, errs = {}, {}

    async.forEachTable(docroots, function(site_name, site_path, tableCb)
      walk(site_path, function(err, filesList)
        if err or not filesList or not next(filesList) then
          safeMerge(errs, err)
          return cb(errs or 'No files found')
        end

        async.forEachLimit(filesList, 5, function(filePath, limitCb)
          if filePath:find('wp%-config.php') then
            -- /var/www/html/wp-config.php ->   ["/var/www/html/"]
            local data = filePath:sub(1, filePath:find('wp%-config')-1)
            found[site_name] = {path = data}
            --    found[site_name] = {path = filePath}
            async.parallel({
              function(parallelCb)
                getVersion(data, function(err, version)
                  if err then
                    safeMerge(errs, err)
                  else
                    found[site_name].version = version
                  end
                  parallelCb()
                end)
              end,
              function(parallelCb)
                getPlugins(data, function(err, plugins)
                  if err then
                    safeMerge(errs, err)
                  else
                    found[site_name].plugins = plugins
                  end
                  parallelCb()
                end)
              end
            }, limitCb)
          else
            limitCb()
          end
        end, tableCb)
      end)
    end, function()
      cb(errs, found)
    end)
  end

  local outTable, errTable = {}, {}
  local function finalCb()
    self:_pushParams(errTable, outTable)
    callback()
  end

  async.series({
    function(cb)
      getDocroots(function(err, docroots)
        if not docroots or not next(docroots) then
          if err then safeMerge(errTable, err) end
          return cb()
        end
        safeMerge(outTable, {docroots = docroots})
        cb()
      end)
    end,
    function(cb)
      if not outTable.docroots or not next(outTable.docroots) then return cb() end
      findWordpress(outTable.docroots, function(err, found)
        if not found then
          if err then safeMerge(errTable, err) end
          return cb()
        end
        safeMerge(outTable, {found = found})
        cb()
      end)
    end
  }, finalCb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'WORDPRESS'
end

exports.Info = Info
exports.VersionReader = VersionReader
exports.PluginsReader = PluginsReader
