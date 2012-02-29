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

local math = require('math')
local path = require('path')
local fs = require('fs')
local os = require('os')

local exports = {}

local misc = require('monitoring/lib/util/misc')
local fsUtil = require('monitoring/lib/util/fs')

exports['test_mkdirp'] = function(test, asserts)
  local separator, component, components, fulPath

  components = {}
  components[1] = path.root

  if os.type() == 'win32' then
    -- TODO: Should eventually move to util/fs
    components[2] = 'Temp'
  else
    components[2] = 'tmp'
  end

  for i=3,6 do
    component = 'test' .. tostring(math.random(0, 1000))
    components[i] = component
  end

  fullPath = path.join(unpack(components))

  asserts.not_ok(fs.existsSync(fullPath))

  fsUtil.mkdirp(fullPath, 0755, function(err)
    asserts.ok(not err)
    asserts.ok(fs.existsSync(fullPath))
    test.done()
  end)
end

return exports
