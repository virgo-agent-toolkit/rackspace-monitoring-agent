--[[
Copyright 2012 Rackspace

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
local Client = require('./init').Client
local JSON = require('json')

local client = Client:new('', '', {})
client.entities.get(function(err, results)
  if err then
    p(err)
    return
  end
  for k, v in pairs(results.values) do
    print('ID = ' .. v.id)
    print('  LABEL = ' .. v.label)
    print('  MANAGED = ' .. tostring(v.managed))
    print('  IP_ADDRESSES = ' .. JSON.stringify(v.ip_addresses))
    print('')
  end
end)

