--[[
Copyright 2014 Rackspace

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
local Agent = require('/agent').Agent
local async = require('async')
local exports = {}

exports['test_load_endpoints'] = function(test, asserts)
  async.series({
    function(callback)
      -- Test Service Net
      local serviceNets = {
        'dfw',
        'ord',
        'lon',
        'syd',
        'hkg',
        'iad'
      }
      local function iter(location, callback)
        local options = {
          ['config'] = {
            ['query_endpoints'] = nil,
            ['endpoints'] = nil,
            ['snet_region'] = location
          }
        }
        local ag = Agent:new(options)
        ag:loadEndpoints(function(err, endpoints)
          asserts.ok(err == nil)
          asserts.ok(#endpoints == 3)
          for i, _ in ipairs(endpoints) do
            asserts.ok(endpoints[i]['srv_query']:find('snet%-'..location) ~= nil)
          end
          callback()
        end)
      end
      async.forEach(serviceNets, iter, callback)
    end,
    function(callback)
      -- Test 1 Custom Endpoints
      local options = {
        ['config'] = {
          ['query_endpoints'] = nil,
          ['endpoints'] = '127.0.0.1:5040',
          ['snet_region'] = nil
        }
      }
      local ag = Agent:new(options)
      ag:loadEndpoints(function(err, endpoints)
        asserts.ok(err == nil)
        asserts.ok(#endpoints == 1)
        asserts.ok(endpoints[1].host == '127.0.0.1')
        asserts.ok(endpoints[1].port== 5040)
        callback()
      end)
    end,
    function(callback)
      -- Test 3 Custom Endpoints
      local options = {
        ['config'] = {
          ['query_endpoints'] = nil,
          ['endpoints'] = '127.0.0.1:5040,127.0.0.1:5041,127.0.0.1:5042',
          ['snet_region'] = nil
        }
      }
      local ag = Agent:new(options)
      ag:loadEndpoints(function(err, endpoints)
        asserts.ok(err == nil)
        asserts.ok(#endpoints == 3)
        asserts.ok(endpoints[1].host == '127.0.0.1')
        asserts.ok(endpoints[1].port== 5040)
        asserts.ok(endpoints[2].host == '127.0.0.1')
        asserts.ok(endpoints[2].port== 5041)
        asserts.ok(endpoints[3].host == '127.0.0.1')
        asserts.ok(endpoints[3].port== 5042)
        callback()
      end)
    end,
    function(callback)
      -- Test query_endpoints
      local options = {
        ['config'] = {
          ['query_endpoints'] = 'srv1,srv2,srv3',
          ['endpoints'] = nil,
          ['snet_region'] = nil
        }
      }
      local ag = Agent:new(options)
      ag:loadEndpoints(function(err, endpoints)
        asserts.ok(err == nil)
        asserts.ok(#endpoints == 3)
        p(endpoints)
        for i, _ in ipairs(endpoints) do
          asserts.ok(endpoints[i]['srv_query']:find('srv'..i) ~= nil)
        end
        callback()
      end)
    end
  }, function(err)
    asserts.ok(err == nil)
    test.done()
  end)
end

return exports
