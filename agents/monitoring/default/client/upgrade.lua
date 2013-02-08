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
local Emitter = require('core').Emitter
local timer = require('timer')
local consts = require('../util/constants')
local misc = require('../util/misc')
local logging = require('logging')

local UpgradePollEmitter = Emitter:extend()

function UpgradePollEmitter:initialize()
  self.stopped = nil
  self.options = nil
end

function UpgradePollEmitter:calcTimeout()
  return misc.calcJitter(consts.UPGRADE_INTERVAL, consts.UPGRADE_INTERVAL_JITTER)
end

function UpgradePollEmitter:_emit()
  process.nextTick(function()
    self:emit('upgrade', self.options)
  end)
end

function UpgradePollEmitter:forceUpgradeCheck(options)
  self.options = misc.merge(self.options or {}, options)
  self:_emit()
end

function UpgradePollEmitter:_registerTimeout()
  if self.stopped then
    return
  end
  -- Check for upgrade
  local timeoutCallback
  timeoutCallback = function()
    self:_emit()
    self:_registerTimeout()
  end

  local timeout = self:calcTimeout()
  logging.debugf('Using Upgrade Timeout %ums', timeout)
  self._timer = timer.setTimeout(timeout, timeoutCallback)
end

function UpgradePollEmitter:start()
  self.stopped = nil

  if self._timer then
    return
  end

  -- On Startup check for upgrade
  self:_emit()
  self:_registerTimeout()
end

function UpgradePollEmitter:stop()
  if self._timer then
    timer.clearTimer(self._timer)
  end
  self.stopped = true
end

local exports = {}
exports.UpgradePollEmitter = UpgradePollEmitter
return exports
