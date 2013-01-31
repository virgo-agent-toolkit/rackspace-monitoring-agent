local bind = require('utils').bind
local timer = require('timer')
local Emitter = require('core').Emitter
local Object = require('core').Object
local misc = require('../util/misc')
local logging = require('logging')
local loggingUtil = require ('../util/logging')
local path = require('path')
local util = require('../util/misc')
local consts = require('../util/constants')
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
    if err then
      return callback(err)
    end
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

function ConnectionMessages:getUpgrade(version, client)
  local bundle_files = {
    [1] = {
      payload = 'monitoring.zip',
      signature = 'monitoring.zip.sig',
      path = virgo_paths.get(virgo_paths.VIRGO_PATH_BUNDLE_DIR)
    }
  }
  local channel = self._connectionStream:getChannel()
  local unverified_dir = path.join(consts.DEFAULT_DOWNLOAD_PATH, 'unverified')
  local AbortDownloadError = errors.Error:extend()
  local SigVerifyError = errors.Error:extend()

  async.waterfall({
    function(callback)
      fsutil.mkdirp(unverified_dir, "0755", function(err)
        if not err then return callback() end
        if err.code == "EEXIST" then return callback() end
        callback(err)
      end)
    end,
    function(callback)
      local function download_iter(item, callback)
        local options = {
          method = 'GET',
          host = client._host,
          port = client._port,
          tls = client._tls_options,
        }
        async.parallel({
          payload = function(callback)
            local opts = misc.merge({
              path = fmt('/upgrades/%s/%s', channel, item.payload),
              download = path.join(unverified_dir, item.payload)
            }, options)
            request.makeRequest(opts, callback)
          end,
          signature = function(callback)
            local opts = misc.merge({
              path = fmt('/upgrades/%s/%s', channel, item.signature),
              download = path.join(unverified_dir, item.signature)
            }, options)
            request.makeRequest(opts, callback)
          end
        }, function(err)
          if err then
            return callback(err)
          end
          local filename = path.join(unverified_dir, item.payload)
          local filename_sig = path.join(unverified_dir, item.signature)
          local filename_verified = path.join(item.path, item.payload)
          local filename_verified_sig = path.join(item.path, item.signature)
          self:verify(filename, filename_sig, process.cwd() .. '/tests/ca/server.pem', function(err)
            if err then
              return callback(err)
            end
            async.parallel({
              function(callback)
                fs.rename(filename, filename_verified, callback)
              end,
              function(callback)
                fs.rename(filename_sig, filename_verified_sig, callback)
              end
            }, callback)
          end)
        end)
      end
      async.forEach(bundle_files, download_iter, callback)
    end
  }, function(err)
    if err then
      client:log(logging.ERROR, fmt('Error downloading update: %s', tostring(err)))
      return
    end
    local msg = 'An update to the Rackspace Cloud Monitoring Agent has been downloaded'
    client:log(logging.INFO, msg)
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
      client:log(logging.INFO, fmt('error handling %s %s', method, err))
      return
    end

    if method == 'check_schedule.changed' then
      self._lastFetchTime =   0
      client:log(logging.DEBUG, 'fetching manifest')
      self:fetchManifest(client)
      return
    end

    if method == 'binary_upgrade.available' then
      return self:getUpgrade('binary', client)
    elseif method == 'bundle_upgrade.available' then
      return self:getUpgrade('bundle', client)
    end

    client:log(logging.DEBUG, fmt('No handler for method: %s', method))
  end

  client.protocol:respond(method, msg, callback)
end

local exports = {}
exports.ConnectionMessages = ConnectionMessages
return exports
