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

local us = require('virgo/util/underscore')

local FEATURE_UPGRADES = { name = 'upgrades', version = '1.0.0' }
local FEATURE_CONFD = { name = 'confd', version = '1.0.0' }
local FEATURE_HEALTH = { name = 'health', version = '1.0.0' }
local FEATURE_POLLER = { name = 'poller', version = '1.0.0' }

local FEATURES = {
  FEATURE_UPGRADES,
  FEATURE_CONFD,
  FEATURE_HEALTH,
  FEATURE_POLLER
}

local function disable(name, remove)
  for i, v in pairs(FEATURES) do
    if v.name == name then
      if remove then
        table.remove(FEATURES, i)
      else
        v.disabled = true
      end
      break
    end
  end
end

local function get(name)
  if not name then return FEATURES end
  for _, v in pairs(FEATURES) do
    if v.name == name then return v end
  end
  return
end

local function disableWithOption(option, name, remove)
  if not option then return end
  option = option:lower()
  if option == 'disabled' or option == 'false' then
    disable(name, remove)
  end
end

local function setParams(name, params)
  local feature = get(name)
  if not feature then return end
  us.extend(feature, { params = params })
end

exports.get = get
exports.setParams = setParams
exports.disable = disable
exports.disableWithOption = disableWithOption
