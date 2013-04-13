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

local exports = {}

exports['test_virgo_exec_upgrade_logic'] = function(test, asserts)
  asserts.not_ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222', '0.1.7-222'))
  asserts.not_ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222', '0.1.9-222'))
  asserts.not_ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222', '0.2.7-222'))
  asserts.not_ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222', '1.1.7-222'))

  asserts.not_ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222.exe', '0.1.7-222'))
  asserts.not_ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222.exe', '0.1.9-222'))
  asserts.not_ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222.exe', '0.2.7-222'))
  asserts.not_ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222.exe', '1.1.7-222'))

  asserts.ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222', '0.1.7-221'))
  asserts.ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222', '0.1.6-222'))
  asserts.ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222', '0.0.7-222'))

  asserts.ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222.exe', '0.1.7-221'))
  asserts.ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222.exe', '0.1.6-222'))
  asserts.ok(exec.is_new_exe('/foo/rackspace-monitoring-agent-0.1.7-222.exe', '0.0.7-222'))

  test.done()
end

return exports
