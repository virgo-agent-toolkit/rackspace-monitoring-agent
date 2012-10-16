local bind = require('utils').bind
local timer = require('timer')
local Emitter = require('core').Emitter
local Object = require('core').Object
local misc = require('../util/misc')
local logging = require('logging')
local loggingUtil = require ('../util/logging')
local path = require('path')
local util = require('../util/misc')
local table = require('table')
local os = require('os')
local https = require('https')
local fs = require('fs')
local async = require('async')
local fmt = require('string').format
local fsutil = require('../util/fs')
local crypto = require('_crypto')
local errors = require('../errors')
local instanceof = require('core').instanceof
local request = require('../protocol/request')
-- Connection Messages

local ConnectionMessages = Emitter:extend()
function ConnectionMessages:initialize(connectionStream)
  self._connectionStream = connectionStream
  self:on('handshake_success', bind(ConnectionMessages.onHandshake, self))
  self:on('client_end', bind(ConnectionMessages.onClientEnd, self))
  self:on('message', bind(ConnectionMessages.onMessage, self))
  self._lastFetchTime = 0
end

function ConnectionMessages:getStream()
  return self._connectionStream
end

function ConnectionMessages:onClientEnd(client)
  client:log(logging.INFO, 'Detected client disconnect')
end

function ConnectionMessages:onHandshake(client, data)
  -- Only retrieve manifest if agent is bound to an entity
  if data.entity_id then
    self:fetchManifest(client)
  else
    client:log(logging.DEBUG, 'Not retrieving check manifest, because ' ..
                              'agent is not bound to an entity')
  end
end

function ConnectionMessages:fetchManifest(client)
  function run()
    if client then
      client:log(logging.DEBUG, 'Retrieving check manifest...')

      client.protocol:request('check_schedule.get', function(err, resp)
        if err then
          -- TODO Abort connection?
          client:log(logging.ERROR, 'Error while retrieving manifest: ' .. err.message)
        else
          client:scheduleManifest(resp.result)
        end
      end)
    end
  end

  if self._lastFetchTime == 0 then
    if self._timer then
      timer.clearTimer(self._timer)
    end
    self._timer = process.nextTick(run)
    self._lastFetchTime = os.time()
  end
end

function ConnectionMessages:verify(path, sig_path, kpub_path, callback)

  local parallel = {
    hash = function(callback)
      local hash = crypto.verify.new('sha256')
      local stream = fs.createReadStream(path)
      stream:on('data', function(d)
        hash:update(d)
      end)
      stream:on('end', function() 
        callback(nil, hash)
      end)
      stream:on('error', callback)
    end,
    sig = function(callback)
      fs.readFile(sig_path, callback)
    end,
    pub_data = function(callback)
      fs.readFile(kpub_path, callback)
    end
  }
  async.parallel(parallel, function(err, res)
    if err then return callback(err) end
    local hash = res.hash[1]
    local sig = res.sig[1]
    local pub_data = res.pub_data[1]
    local key = crypto.pkey.from_pem(pub_data)

    if not key then 
      return callback(errors.InvalidSignatureError:new('invalid key file'))
    end

    if not hash:final(sig, key) then
      return callback(errors.InvalidSignatureError:new('invalid sig on file: '.. path))
    end

    callback()
  end)
end

function ConnectionMessages:getUpdate(method, client)
  local dir, filename, version, extension, AbortDownloadError, temp_dir, unverified_dir, update_type, download_attempts

  AbortDownloadError = errors.Error:extend()
  temp_dir = virgo_paths.get(virgo_paths.VIRGO_PATH_TMP_DIR)
  unverified_dir = path.join(temp_dir, 'unverified')
  filename = virgo.default_name
  extension = ""
  download_attempts = 2

  if method == "bundle_upgrade.available" then
    update_type = "bundle"
  elseif method == "binary_upgrade.available" then
    update_type = "binary"
    extension = ".zip"
  end

  local function get_path(arg)
    local sig = arg and arg.sig and '.sig' or ""
    local verified = arg and arg.verified
    local name = filename..'-'..version..extension..sig

    local _dir = unverified_dir
    if verified then
      if update_type == "binary" then
        _dir = temp_dir
      else 
        _dir = virgo_paths.get(virgo_paths.VIRGO_PATH_BUNDLE_DIR)
      end
    end
    return path.join(_dir, name)
  end

  async.waterfall({
    function(callback)
      fsutil.mkdirp(unverified_dir, "0755", function(err)
        if not err then return callback() end
        if err.code == "EEXIST" then return callback() end
        callback(err)
      end)
    end,
    function(callback)
      client.protocol:request(update_type ..'_upgrade.get_version', callback)
    end,
    function(res, callback)
      version = res.result.version

      async.parallel({
        function(callback)
          fs.exists(get_path{verified=true}, callback)
        end,
        function(callback)
          fs.exists(get_path{verified=true, sig=true}, callback)
        end,
      }, callback)
    end,
    function(res, callback)
      local sig, update

      sig, update = unpack(res)

      -- Early return from waterfall
      if sig[1] == true and update[1] == true then
        return callback(AbortDownloadError:new())
      end
      
      local uri_path = fmt('/upgrades/%s/%s', update_type, version)
      if update_type == 'binary' then 
        uri_path = uri_path .. '/' .. virgo.platform
      end

      client:log(logging.INFO, fmt('fetching version %s and its sig for %s', version, update_type))

      async.parallel({
        function(callback)
          local options = {
            method = 'GET',
            path = uri_path,
            download = get_path(),
            host = client._host,
            port = client._port,
            tls = client._tls_options
          }
          request.makeRequest(options, callback)
        end,
        function(callback)
          local options = {
            method = 'GET',
            path = uri_path ..'.sig',
            download = get_path{sig=true},
            host = client._host,
            port = client._port,
            tls = client._tls_options
          }
          request.makeRequest(options, callback)
        end
      }, callback)
    end,
    function(res, callback)
      client:log(logging.DEBUG, 'Downloaded update and sig')
      self:verify(get_path(), get_path{sig=true}, process.cwd()..'/tests/ca/server.pem', callback)
    end,
  function(res, callback)

    async.parallel({
      function(callback) 
        fs.rename(get_path(), get_path{verified=true}, callback)
      end,
      function(callback)
        fs.rename(get_path{sig=true}, get_path{sig=true, verified=true}, callback)
      end
      }, callback)
  end}, 
  function(err, res)
    if not err then
      local msg = 'An update to the Rackspace Cloud Monitoring Agent has been downloaded to ' .. 
      get_path{verified=true} .. 'and is ready to use. Please restart the agent.'
      client:log(logging.INFO, msg)
      return
    end

    if instanceof(err, AbortDownloadError) then
      return client:log(logging.DEBUG, 'already downloaded update, not doing so again')
    end

    client:log(logging.ERROR, fmt('COULD NOT DOWNLOAD UPDATE: %s', tostring(err)))
  end)

end

function ConnectionMessages:onMessage(client, msg)

  local method = msg.method

  if not method then
    client:log(logging.WARNING, fmt('no method on message!'))
    return
  end

  client:log(logging.DEBUG, fmt('received %s', method))

  local callback = function(err, msg)
    if (err) then
      self:emit('error', err)
      client:log(logging.INFO, fmt('error handling %s %s', method, err))
      return
    end

    if method == 'check_schedule.changed' then
      self._lastFetchTime =   0
      client:log(logging.DEBUG, 'fetching manifest')
      self:fetchManifest(client)
      return
    end

    if method == 'binary_upgrade.available' or method == 'bundle_upgrade.available' then
      return self:getUpdate(method, client)
    end

    client:log(logging.DEBUG, fmt('No handler for method: %s', method))
  end

  client.protocol:respond(method, msg, callback)
end

local exports = {}
exports.ConnectionMessages = ConnectionMessages
return exports
