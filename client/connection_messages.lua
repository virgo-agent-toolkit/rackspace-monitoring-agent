local bind = require('utils').bind
local timer = require('timer')
local Emitter = require('core').Emitter
local path = require('path')
local Object = require('core').Object
local table = require('table')
local os = require('os')
local https = require('https')
local fs = require('fs')
local crypto = require('_crypto')
local instanceof = require('core').instanceof
local string = require('string')
local sigar = require('sigar')

local misc = require('../util/misc')
local logging = require('logging')
local loggingUtil = require ('../util/logging')
local consts = require('../util/constants')
local async = require('async')
local fmt = require('string').format
local fsutil = require('../util/fs')
local errors = require('../errors')
local request = require('../protocol/request')

local code_cert
if _G.TESTING_CERTS then
  code_cert = _G.TESTING_CERTS
else
  code_cert = require('../code_cert.prod.lua')
end


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

function ConnectionMessages:verify(path, sig_path, kpub_data, callback)
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
    end
  }
  async.parallel(parallel, function(err, res)
    if err then
      return callback(err)
    end
    local hash = res.hash[1]
    local sig = res.sig[1]
    local pub_data = kpub_data
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

function ConnectionMessages:getUpgrade(version, client, callback)
  local channel = self._connectionStream:getChannel()
  local unverified_dir = consts.DEFAULT_UNVERIFIED_BUNDLE_PATH
  local verified_dir = consts.DEFAULT_VERIFIED_BUNDLE_PATH
  local unverified_binary_dir = consts.DEFAULT_UNVERIFIED_EXE_PATH
  local verified_binary_dir = consts.DEFAULT_VERIFIED_EXE_PATH

  local function download_iter(item, callback)
    local options = {
      method = 'GET',
      host = client._host,
      port = client._port,
      tls = client._tls_options,
    }

    local filename = path.join(unverified_dir, item.payload)
    local filename_sig = path.join(unverified_dir, item.signature)
    local filename_verified = path.join(item.path, item.payload)
    local filename_verified_sig = path.join(item.path, item.signature)

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

      self:verify(filename, filename_sig, code_cert.codeCert, function(err)
        if err then
          return callback(err)
        end
        client:log(logging.INFO, fmt('Signature verified %s (ok)', item.payload))
        async.parallel({
          function(callback)
            client:log(logging.INFO, fmt('Moving file to %s', filename_verified))
            misc.copyFile(filename, filename_verified, callback)
          end,
          function(callback)
            client:log(logging.INFO, fmt('Moving file to %s', filename_verified_sig))
            misc.copyFile(filename_sig, filename_verified_sig, callback)
          end
        }, function(err)
          if err then
            return callback(err)
          end
          fs.chmod(filename_verified, string.format('%o', item.permissions), callback)
        end)
      end)
    end)
  end

  local function mkdirp(path, callback)
    fsutil.mkdirp(path, "0755", function(err)
      if not err then return callback() end
      if err.code == "EEXIST" then return callback() end
      callback(err)
    end)
  end

  local directories = {
    unverified_dir,
    verified_dir,
    unverified_binary_dir,
    verified_binary_dir
  }

  async.waterfall({
    function(callback)
      async.forEach(directories, mkdirp, callback)
    end,
    function(callback)
      local s = sigar:new():sysinfo()
      local binary_name = fmt('%s-%s-%s-monitoring-agent-%s', s.vendor, s.vendor_version, s.arch, version):lower()
      local binary_name_sig = fmt('%s.sig', binary_name)
      local bundle_files = {
        [1] = {
          payload = fmt('monitoring-%s.zip', version),
          signature = fmt('monitoring-%s.zip.sig', version),
          path = virgo_paths.get(virgo_paths.VIRGO_PATH_BUNDLE_DIR),
          permissions = tonumber('644', 8)
        },
        [2] = {
          payload = binary_name,
          signature = binary_name_sig,
          path = virgo_paths.get(virgo_paths.VIRGO_PATH_EXE_DIR),
          permissions = tonumber('755', 8)
        }
      }
      async.forEach(bundle_files, download_iter, callback)
    end
  }, function(err)
    if err then
      client:log(logging.ERROR, fmt('Error downloading update: %s', tostring(err)))
      return callback(err)
    end
    local msg = 'An update to the Rackspace Cloud Monitoring Agent has been downloaded'
    client:log(logging.INFO, msg)
    return callback()
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
      client:log(logging.INFO, fmt('error handling %s (error: %s)', method, err))
      return
    end

    if method == 'check_schedule.changed' then
      self._lastFetchTime =   0
      client:log(logging.DEBUG, 'fetching manifest')
      self:fetchManifest(client)
      return
    end

     if method == 'binary_upgrade.available' then
      return self:getUpgrade('binary', client, function(err)
        if err then
          client:log(logging.INFO, fmt('error handling %s %s', method, err))
          return
        end
      end)
    elseif method == 'bundle_upgrade.available' then
      return self:getUpgrade('bundle', client, function(err)
        if err then
          client:log(logging.INFO, fmt('error handling %s %s', method, err))
          return
        end
      end)
    end

    client:log(logging.DEBUG, fmt('No handler for method: %s', method))
  end

  client.protocol:respond(method, msg, callback)
end

local exports = {}
exports.ConnectionMessages = ConnectionMessages
return exports
