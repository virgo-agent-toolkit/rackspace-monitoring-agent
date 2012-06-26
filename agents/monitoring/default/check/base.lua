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
local JSON = require('json')
local Emitter = require('core').Emitter
local fmt = require('string').format
local table = require('table')

local toString = require('../util/misc').toString
local tableContains = require('../util/misc').tableContains

local BaseCheck = Emitter:extend()
local CheckResult = Object:extend()
local Metric = Object:extend()

local VALID_METRIC_TYPES = {'string', 'gauge', 'int32', 'uint32', 'int64', 'uint64', 'double'}
local VALID_STATES = {'available', 'unavailable'}


function BaseCheck:initialize(checkType, params)
  self.id = tostring(params.id)
  self.period = tonumber(params.period)
  self._type = checkType

  self._lastResult = nil
end

function BaseCheck:run(callback)
  -- do something, produce a CheckResult
  local checkResult = CheckResult:new(self, {})
  self._lastResult = checkResult
  callback(checkResult)
end

function BaseCheck:getType()
  return self._type
end

function BaseCheck:getNextRun()
  if self._lastResult then
    return self._lastResult._nextRun
  else
    return os.time()
  end
end

function BaseCheck:toString()
  return fmt('%s (id=%s, period=%ss)', self._type, self.id, self.period)
end

function BaseCheck:serialize()
  return {
    id = self.id,
    period = self.period,
    nextrun = self:getNextRun()
  }
end

function CheckResult:initialize(check, options)
  self._options = options or {}
  self._metrics = {}
  self._state = 'available'
  self._status = nil
  self._nextRun = os.time() + check.period
end

function CheckResult:setAvailable()
  self._state = 'available'
end

function CheckResult:setUnavailable()
  self._state = 'unavailable'
end

function CheckResult:getState()
  return self._state
end

function CheckResult:getStatus()
  local status = self._status and self._status or ''
  return status
end

function CheckResult:setStatus(status)
  self._status = status
end

function CheckResult:setError(message)
  self:setUnavailable()
  self:setStatus(message)
end

function CheckResult:addMetric(name, dimension, type, value)
  local metric = Metric:new(name, dimension, type, value)

  if not self._metrics[metric.dimension] then
    self._metrics[metric.dimension] = {}
  end

  self._metrics[metric.dimension][metric.name] = {t = metric.type, v = metric.value}
end

function CheckResult:getMetrics()
  return self._metrics
end

function CheckResult:toString()
  return toString(self)
end


-- Serialize a result to the format which is understood by the endpoint.
function CheckResult:serialize()
  local dimension, metric
  local result = {}

  for dimension, metrics in pairs(self._metrics) do
    if dimension == 'none' then
      dimension = JSON.null
    end

    table.insert(result, {dimension, metrics})
  end

  return result
end

function Metric:initialize(name, dimension, type, value)
  self.name = name
  self.dimension = dimension or 'none'
  self.value = tostring(value)

  if type then
    if not tableContains(function(v) return type == v end, VALID_METRIC_TYPES) then
      error('Invalid metric type: ' .. type)
    end
    self.type = type
  else
    self.type = getMetricType(value)
  end
end


-- Determinate the metric type based on the value type.
function getMetricType(value)
  local valueType = type(value)

  if valueType == 'string' then
    -- TODO gauge
    return 'string'
  elseif valueType == 'boolean' then
    return 'bool'
  elseif valueType == 'number' then
    if not tostring(value):find('%.') then
      -- TODO int32, uint32, uint64
      return 'int64'
    else
      return 'double'
    end
  end
end

local exports = {}
exports.VALID_METRIC_TYPES = VALID_METRIC_TYPES
exports.BaseCheck = BaseCheck
exports.CheckResult = CheckResult
exports.Metric = Metric
return exports
