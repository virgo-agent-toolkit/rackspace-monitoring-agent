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

local AgentProtocolConnection = require('virgo/protocol/connection')
local loggingUtil = require ('virgo/util/logging')
local stream = require('stream')

require('../tap')(function(test)
  test('test completion key', function()
    local sock = stream.Readable:new()
    sock._read = function() end
    local conn = AgentProtocolConnection:new(loggingUtil.makeLogger(), 'MYID', 'TOKEN', 'GUID', sock)
    assert('GUID:1' == conn:_completionKey('1'))
    assert('hello:1' == conn:_completionKey('hello', '1'))
  end)
end)
