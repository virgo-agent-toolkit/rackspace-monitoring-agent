--[[
Copyright 2014 Rackspace

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

function isStaging()
  virgo.config = virgo.config or {}
  local b = virgo.config['monitoring_use_staging']
  b = process.env.STAGING or (b and b:lower() == 'true')
  if b then
    process.env.STAGING = 1
  end
  return b
end

local exports = {}
exports.isStaging = isStaging
return exports
