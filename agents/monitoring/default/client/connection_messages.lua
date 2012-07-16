local bind = require('utils').bind
local timer = require('timer')
local Emitter = require('core').Emitter
local Object = require('core').Object
local misc = require('../util/misc')
local logging = require('logging')
local loggingUtil = require ('../util/logging')
local table = require('table')
local os = require('os')

local fmt = require('string').format

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

      client.protocol:getManifest(function(err, manifest)
        if err then
          -- TODO Abort connection?
          client:log(logging.ERROR, 'Error while retrieving manifest: ' .. err.message)
        else
          client:scheduleManifest(manifest)
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

function ConnectionMessages:onMessage(client, msg)
  client:log(logging.DEBUG, '(onMessage)')
  if msg.method == 'check_schedule.changed' then
    self._lastFetchTime = 0
    client:log(logging.DEBUG, 'received schedule change')
    client.protocol:respond(msg.method, msg, function ()
      client:log(logging.DEBUG, 'fetching manifest')
      self:fetchManifest(client)
    end)
  elseif msg.method == 'host_info.get' then
    client:log(logging.DEBUG, 'received host info request ' .. msg.params.type or 'UNDEFINED')
    client.protocol:respond(msg.method, msg, function()
    end)
  end
end

local exports = {}
exports.ConnectionMessages = ConnectionMessages
return exports
