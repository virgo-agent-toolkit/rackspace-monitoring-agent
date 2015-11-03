--[[
Copyright 2015 Rackspace

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local HostInfo = require('./base').HostInfo
local walk = require('luvit-walk').readdirRecursive
local async = require('async')
local Transform = require('stream').Transform
local Apache2 = require('./apache2')
local Nginx = require('./nginx_config')
local misc = require('./misc')

------------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(line, cb)
  local versionOpts = {
    major = true,
    minor = true,
    revision = true,
    patch = true,
    stability = true,
    number = true
  }

  if line:find('=>') then
    local name, version = line:match("'(%S+)'%s*%=%>%s*'(%S+)'")
    if versionOpts[name] then
      self:push({version = {
        name = name,
        version = version
      }})
    end
  elseif line:find('const%sEDITION_') then
    local identifier, version = line:match("(EDITION_%S+)%s*%=%s*'(%S+)';")
    self:push({editionList = {[identifier] = version}})
  elseif line:find('static private $_currentEdition') then
    self:push({editionAssign = line:match('%:%:(%S+);')})
  end

  cb()
end
------------------------------------------------------------------------------------------------------------------------

--[[ MAGENTO ]]--
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
            misc.safeMerge(errs, err)
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
            misc.safeMerge(errs, err)
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

  local function getVersionAndEdition(path, cb)
    local readStream = misc.read(path)
    readStream:on('error', function(err)
      cb(err) -- has to be a no file found error at this stage
    end)

    local versionString = ''
    local editions = {}
    local edition = 'Unknown'

    local reader = Reader:new()
    readStream:pipe(reader)
    reader:on('data', function(data)
      if data.version then
        versionString = versionString .. data.version.version .. '.'
      elseif data.editionList then
        misc.safeMerge(editions, data.editionList)
      elseif data.editionAssign then
        edition = editions[data.editionAssign]
      end
    end)

    reader:once('end', function()
      cb(nil, {
        edition = edition,
        version = versionString:sub(1, versionString:len() - 1)
      })
    end)
  end

  local function findMagento(docroots, cb)
    local found, errs = {}, {}

    async.forEachTable(docroots, function(site_name, site_path, tableCb)
      walk(site_path, function(err, filesList)
        if err or not filesList or not next(filesList) then
          misc.safeMerge(errs, err)
          return cb(errs or 'No files found')
        end

        async.forEachLimit(filesList, 5, function(filePath, limitCb)
          if filePath:find('Mage.php') then
            found[site_name] = {path = filePath}
            getVersionAndEdition(filePath, function(err, data)
              if err or not data or not next(data) then
                misc.safeMerge(errs, err)
              elseif data.version and data.edition then
                found[site_name].version = data.version
                found[site_name].edition = data.edition
              end
              limitCb()
            end)
          else
            limitCb()
          end
        end, tableCb)
      end)
    end, function()
      cb(errs, found)
    end)
  end

  local errTable, outTable = {}, {}
  local function finalCb()
    self:_pushParams(errTable, outTable)
    callback()
  end

  local docroots
  async.series({
    function(cb)
      getDocroots(function(err, data)
        misc.safeMerge(errTable, err)
        docroots = data
        cb()
      end)
    end,
    function(cb)
      if not docroots then return cb() end
      findMagento(docroots, function(err, data)
        misc.safeMerge(errTable, err)
        misc.safeMerge(outTable, data)
        cb()
      end)
    end
  }, finalCb)
end

function Info:getType()
  return 'MAGENTO'
end

function Info:getPlatforms()
  return {'linux'}
end

exports.Info = Info
exports.Reader = Reader
