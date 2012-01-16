local Emitter = require('emitter')
local JSON = require('json')
local logging = require('logging')
local net = require('net')
local utils = require('utils')

local AgentClient = {}
utils.inherits(AgentClient, Emitter)

function AgentClient.prototype:simple_request(method, params)
  local request = {}
  request.v = 1
  request.id = self._id
  request.source = self._source
  request.method = method
  request.params = params
  self._conn:write(JSON.stringify(request) .. '\n')
  self._id = self._id + 1
end

function AgentClient.prototype:process_line(line)
  local message = JSON.parse(line)
  logging.log(logging.DBG, 'client:process_line:' .. line)
  self:emit('message', message)
end

function AgentClient.prototype:on_data(data)
  newline = data:find("\n")
  if newline then
    -- TODO: use a better buffer
    self._buf = self._buf .. data:sub(1, newline - 1)
    self:process_line(self._buf)
    self._buf = data:sub(newline)
  else
    self._buf = self._buf .. data
  end
end

function AgentClient.prototype:close()
  self._conn:close()
end

function AgentClient.connect(source, host, port, callback)
  local ap = AgentClient.new_obj()
  ap._source = source
  ap._id = 0
  ap._buf = ""
  ap._conn = net.create(port, host, function(err)
    if err then
      callback(err)
      return
    end
    callback(nil, ap)
  end)
  ap._conn:on('data', utils.bind(ap, AgentClient.prototype.on_data))

  ap._methods = {}
  ap._methods["handshake.hello"] = utils.bind(ap, AgentClient.prototype.handshake_hello)
  return ap
end

return AgentClient
