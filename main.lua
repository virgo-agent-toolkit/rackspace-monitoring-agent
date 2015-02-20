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

local luvi = require('luvi')
luvi.bundle.register('require', "modules/require.lua")
local require = require('require')()("bundle:main.lua")

local options = {}
options.version = require('./package').version
options.pkg_name = "rackspace-monitoring-agent"
options.paths = {}
options.paths.persistent_dir = "/var/lib/rackspace-monitoring-agent"
options.paths.exe_dir = "/var/lib/rackspace-monitoring-agent/exe"
options.paths.config_dir = "/etc"
options.paths.library_dir = "/usr/lib/rackspace-monitoring-agent"
options.paths.runtime_dir = "/var/run/rackspace-monitoring-agent"

return require('luvit')(function (...)
  local args = { ... }
  require('virgo')(options)
  require('./lib/main')(unpack(args))
end)
