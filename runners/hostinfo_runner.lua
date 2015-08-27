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
local HostInfo = require('../hostinfo')
local upper = require('string').upper
local json = require('json')

local function run(...)
  local argv, typeName, klass
  argv = require("options")
    .usage('Usage: -x [Host Info Type]')
    .describe("x", "host info type to run")
    .usage('Usage: -d [filename]')
    .describe("d", "write debug info to file")
    .argv("x:d:")

  local args = argv.args
  if args.d then
    local filename = argv.args.d
    return HostInfo.debugInfo(filename, print('Debug info written to file '..filename))
  elseif args.x then
    typeName = upper(argv.args.x)
    klass = HostInfo.create(typeName)
    return klass:run(function(err)
      if err then
        print(json.stringify({error = err}))
      else
        print(json.stringify(klass:serialize()))
      end
    end)
  else
    print(argv._usage)
    return process:exit(0)
  end
end

return { run = run }
