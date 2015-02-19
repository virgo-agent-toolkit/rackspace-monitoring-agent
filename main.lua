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

_G.virgo = {}
_G.virgo_paths = {}
_G.virgo.virgo_version = "1.9.0" -- TODO
_G.virgo.bundle_version = _G.virgo.virgo_version

function _G.virgo_paths.get() end

-- Create a luvit powered main that does the luvit CLI interface
return require('luvit')(function (...)
  require('./lib/main')
end)
