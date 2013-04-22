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

local core = require('core')

local fs = require('fs')
local path = require('path')

local async = require('async')
local vutils = require('virgo_utils')

local exports = {}
local Error = core.Error;

local BUNDLE_PREFIX = virgo.default_name ..'-bundle'

local times = {
  --   T1          T2          T3           T4     Delta
  {1234567890, 1234567890, 1234567890, 1234567890, 0       },
  {1234567890, 1234567900, 1234567900, 1234567890, 10       },
  {1234567890, 1234567880, 1234567880, 1234567890, -10       },
}

local dump_bundle = function(dir, name, cb)
  local abs_dir = path.join(TEST_DIR, dir)

  fs.mkdir(abs_dir, "0755", function(err)
    if err and err.code ~= 'EEXIST' then
      return cb(err)
    end
    local file_path = path.join(abs_dir, name)

    fs.writeFile(file_path, "", function(err)
      return cb(err, file_path)
    end)
  end)
end

exports['test_vtime'] = function(test, asserts)
  for k, v in pairs(times) do
    vutils.timesync(v[1], v[2], v[3], v[4])
    asserts.ok(vutils.getDelta() == v[5])
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
    asserts.is_nil(err)
    test.done()
  end)
end

local bundle_iter = function(dir, name, asserts, cb)
  dump_bundle(dir, name, function(err, file_path)
    asserts.is_nil(err, tostring(err))
    virgo_paths.set_bundle_path(path.join(TEST_DIR, dir))
    asserts.ok(virgo_paths.get(virgo_paths.VIRGO_PATH_BUNDLE) == file_path)
    cb()
  end)
end

exports['test_bundle_path_a'] = function(test, asserts)
  async.forEachSeries({BUNDLE_PREFIX .. '-0.0.0.zip', BUNDLE_PREFIX .. '-0.0.1.zip', BUNDLE_PREFIX .. '-0.0.2.zip', BUNDLE_PREFIX .. '-0.0.3.zip'},
    function(name, cb)
      return bundle_iter('a', name, asserts, cb)
    end,
    function(err)
      asserts.is_nil(err)
      test.done()
    end
  )
end

exports['test_bundle_path_b'] = function(test, asserts)
  async.forEachSeries({BUNDLE_PREFIX .. '-0.0.1.zip', BUNDLE_PREFIX .. '-1.0.1.zip'},
    function(name, cb)
      return bundle_iter('b', name, asserts, cb)
    end,
    function(err)
      asserts.is_nil(err)
      test.done()
    end
  )
end

exports['test_bundle_path_c'] = function(test, asserts)
  dump_bundle('c', 'collector-1.0.0.zip', function()
    async.forEachSeries({BUNDLE_PREFIX .. '-0.0.5.zip', BUNDLE_PREFIX .. '-0.1.0.zip'},
      function(name, cb)
        return bundle_iter('c', name, asserts, cb)
      end,
      function(err)
        asserts.is_nil(err)
        test.done()
      end
    )
  end)
end

exports['test_virgo_items'] = function(test, asserts)
  asserts.ok(virgo.os)
  asserts.ok(virgo.version)
  asserts.ok(virgo.platform)
  asserts.ok(virgo.default_name)
  asserts.ok(virgo.default_config_filename)

  test.done()
end

exports['test_virgo_static'] = function(test, asserts)
  local data = get_static(path.posix:join('static', 'asdf'))
  asserts.ok(data=="asdf")
  test.done()
end

return exports
