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

local os = require('os')

local exports = {}

exports['test_luacom_processor_list'] = function(test, asserts)
  if os.type() == 'win32' then
    local objWMIService = luacom.GetObject ("winmgmts:{impersonationLevel=Impersonate}!\\\\.\\root\\cimv2")
    local colProcessors = objWMIService:ExecQuery("SELECT * FROM Win32_Processor")
    local success = False
    for index,item in luacom.pairs (colProcessors) do
      p(index, item:Name())
      success = True
    end
    asserts.ok(success == True)
    test.done()
  else
    test.skip("LuaCOM unsupported on " .. os.type())
  end
end

exports['test_luacom_processor_system_data'] = function(test, asserts)
  if os.type() == 'win32' then
    local objWMIService = luacom.GetObject ("winmgmts:{impersonationLevel=Impersonate}!\\\\.\\root\\cimv2")
    local colProcessors = objWMIService:ExecQuery("SELECT * FROM Win32_PerfRawData_PerfOS_System")
    local success = False
    for index,item in luacom.pairs (colProcessors) do
      success = True
      p("Processes", item:Processes())
      p("ProcessorQueueLength", item:ProcessorQueueLength())
    end
    asserts.ok(success == True)
    test.done()
  else
    test.skip("LuaCOM unsupported on " .. os.type())
  end
end

return exports
