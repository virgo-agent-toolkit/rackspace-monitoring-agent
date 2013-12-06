--[[
Copyright 2013 Rackspace

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

local AgentProtocolConnection = require('/protocol/connection')
local Emitter = require('core').Emitter

local loggingUtil = require ('/util/logging')
local fixtures = require('/tests/fixtures')

local async = require('async')

local function fixtureWriter(sock, name)
  local data = fixtures[name]
  assert(data ~= nil)
  sock.write = function()
    process.nextTick(function()
      sock:emit('data', data .. "\n")
    end)
  end
end

local exports = {}

exports['test_db_checks_create'] = function(test, asserts)
  local sock = Emitter:new()
  local conn = AgentProtocolConnection:new(loggingUtil.makeLogger(),
                                           'MYID', 'TOKEN', 'GUID', sock)

  async.series({
    function(callback)
      fixtureWriter(sock, 'handshake.hello.response')
      conn:startHandshake(callback)
    end,
    function(callback)
      local params = {
        label = 'automagic',
        type = 'agent.memory'
      }
      fixtureWriter(sock, 'db_checks.create.response')
      conn:dbCreateChecks('enAAAAIPV4', params, callback)
    end
  }, function(err)
    asserts.equals(err, nil)
    test.done()
  end)
end

exports['test_db_checks_get'] = function(test, asserts)
  local sock = Emitter:new()
  local conn = AgentProtocolConnection:new(loggingUtil.makeLogger(),
                                           'MYID', 'TOKEN', 'GUID', sock)

  async.series({
    function(callback)
      fixtureWriter(sock, 'handshake.hello.response')
      conn:startHandshake(callback)
    end,
    function(callback)
      local enId = 'enAAAAIPV4'
      local chId = 'chAAAA'
      fixtureWriter(sock, 'db_checks.get.response')
      conn:dbGetChecks(enId, chId, function(err, msg)
        asserts.equals(err, nil)
        asserts.equals(msg.result.id, chId)
        callback()
      end)
    end
  }, function(err)
    asserts.equals(err, nil)
    test.done()
  end)
end

return exports
