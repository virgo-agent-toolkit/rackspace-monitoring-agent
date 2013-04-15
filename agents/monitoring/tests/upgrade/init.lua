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


local exec = require('virgo_exec')
local string = require('string')

local exports = {}

local function test_instance_is_newer_logic(exe, version)
  newer = exec.is_new_exe(exe, version)
  p('exe:', exe, 'version:', version, 'newer:', newer)
  return newer
end

exports['test_virgo_exec_upgrade_is_newer_logic'] = function(test, asserts)
  local prefix = '/foo/rackspace-monitoring-agent'
  local version_format = '%d.%d.%d-%d'
  local extensions = {'', '.exe'}

  --Move each number in the file version up 1, up 11, and down 1, alternating with a file extension 

  for x, extension in ipairs(extensions) do
    local movements = {1, 11, -1}
    for y, movement in ipairs(movements) do
      for i = 1,4 do
        local current_versions = {5, 5, 5, 5}
        local file_versions = {5, 5, 5, 5}
        file_versions[i] = file_versions[i] + movement
        exe = string.format('%s' .. '-' .. version_format .. '%s', prefix, file_versions[1], file_versions[2], file_versions[3], file_versions[4], extension) 
        version = string.format(version_format, current_versions[1], current_versions[2], current_versions[3], current_versions[4])
        newer = test_instance_is_newer_logic(exe, version)
        if movement < 0 then
          asserts.not_ok(newer)
        else
          asserts.ok(newer)
        end
      end
    end

    --check plain filename
    asserts.not_ok(test_instance_is_newer_logic(prefix .. extension, string.format(version_format, 5, 5, 5, 5)))
  end

  --check no filename
  asserts.not_ok(test_instance_is_newer_logic('', string.format(version_format, 5, 5, 5, 5)))

  test.done()
end

return exports
