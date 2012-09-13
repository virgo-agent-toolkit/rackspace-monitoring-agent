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

local Error = require('core').Error
local async = require('async')
local vtime = require('virgo-time')
local fs = require('fs')
local path = require('path')
local table = require('table')

local times = {
  --   T1          T2          T3           T4     Delta
  {1234567890, 1234567890, 1234567890, 1234567890, 0       },
  {1234567890, 1234567900, 1234567900, 1234567890, 10       },
  {1234567890, 1234567880, 1234567880, 1234567890, -10       },
}

local exports = {}

exports['test_vtime'] = function(test, asserts)
  for k, v in pairs(times) do
    vtime.timesync(v[1], v[2], v[3], v[4])
    asserts.ok(vtime.getDelta() == v[5])
  end
  test.done()
end

exports['test_paths'] = function(test, asserts)
  local paths = {
    virgo_paths.get(virgo_paths.VIRGO_PATH_CONFIG_DIR),
    virgo_paths.get(virgo_paths.VIRGO_PATH_RUNTIME_DIR),
    virgo_paths.get(virgo_paths.VIRGO_PATH_PERSISTENT_DIR),
    virgo_paths.get(virgo_paths.VIRGO_PATH_TMP_DIR),
    virgo_paths.get(virgo_paths.VIRGO_PATH_LIBRARY_DIR)
  }

  function iter(path, callback)
    fs.stat(path, function(err, stats)
      if err then
        if err.code == 'ENOENT' then
          callback()
          return
        end
        callback(err)
        return
      end
      if stats.is_directory == true then
        callback()
      else
        callback(Error:new('Not a directory ' .. path))
      end
    end)
  end

  async.forEach(paths, iter, function(err)
    asserts.ok(err == nil)
    test.done()
  end)
end

exports['test_bundle_path'] = function(test, asserts)
  local tmpPath = path.join('tests', 'bundles')
  local files = {}

  virgo_paths.set_bundle_path(path.join(tmpPath, 'a'))
  asserts.ok(virgo_paths.get(virgo_paths.VIRGO_PATH_BUNDLE) == 'tests/bundles/a/monitoring-0.0.3.zip')

  virgo_paths.set_bundle_path(path.join(tmpPath, 'b'))
  asserts.ok(virgo_paths.get(virgo_paths.VIRGO_PATH_BUNDLE) == 'tests/bundles/b/monitoring-1.0.0.zip')

  virgo_paths.set_bundle_path(path.join(tmpPath, 'c'))
  asserts.ok(virgo_paths.get(virgo_paths.VIRGO_PATH_BUNDLE) == 'tests/bundles/c/monitoring-0.1.0.zip')

  test.done()
end

return exports
