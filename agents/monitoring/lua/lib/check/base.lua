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

local os = require('os')
local Object = require('core').Object
local Emitter = require('core').Emitter

local BaseCheck = Emitter:extend()
local CheckResult = Object:extend()

function BaseCheck:initialize()
  self._lastResults = nil
end

function BaseCheck:run(callback)
  -- do something, produce a CheckResult
  local checkResult = CheckResult:new({})
  self._lastResults = checkResult
  callback(checkResult)
end

function CheckResult:initialize(options)
  self._nextRun = os.time() + 30; -- default to 30 seconds now.
end


local exports = {}
exports.BaseCheck = BaseCheck
exports.CheckResult = CheckResult
return exports