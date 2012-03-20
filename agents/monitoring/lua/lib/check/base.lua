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
local fmt = require('string').format

local toString = require('../util/misc').toString

local BaseCheck = Emitter:extend()
local CheckResult = Object:extend()
local Metric = Object:extend()


function BaseCheck:initialize(params, checkType)
  self._lastResults = nil
  self._type = checkType or 'UNDEFINED'
  self.state = params.state
  self.id = params.id
  self.period = params.period
  self.path = params.path
end

function BaseCheck:run(callback)
  -- do something, produce a CheckResult
  local checkResult = CheckResult:new({})
  self._lastResults = checkResult
  callback(checkResult)
end

function BaseCheck:getNextRun()
  if self._lastResults then
    return self._lastResults._nextRun
  else
    return os.time()
  end
end

function BaseCheck:toString()
  return fmt('%s (id=%s, period=%ss)', self._type, self.id, self.period)
end

function CheckResult:initialize(check, options, metrics)
  self._options = options or {}
  self._metrics = metrics or {}
  self._nextRun = os.time() + check.period
end

function CheckResult:setMetric(key, value)
  self._metrics[key] = value
end

function CheckResult:toString()
  return toString(self)
end

function CheckResult:setMetricWithObject(metrics)
  for key, value in pairs(metrics) do
    self._metrics[key] = value
  end
end


function Metric:initialize(name, type, dimension, value)
  -- TODO: Figure auto-figure out the type based on the value
  self.name = name
  self.type = type
  self.dimension = dimension or 'default'
  self.value = value
end


-- todo: serialize/deserialize methods.

local exports = {}
exports.BaseCheck = BaseCheck
exports.CheckResult = CheckResult
exports.Metric = Metric
return exports
