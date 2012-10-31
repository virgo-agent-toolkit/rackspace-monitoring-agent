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
  self.timeout = nil
  self.stopped = nil
end

function UpgradePollEmitter:calcTimeout()
  return misc.calcJitter(consts.UPGRADE_INTERVAL, consts.UPGRADE_INTERVAL_JITTER)
end

function UpgradePollEmitter:_emit()
  process.nextTick(function()
    self:emit('upgrade')
  end)
end

function UpgradePollEmitter:_registerTimeout(callback)
  if self.stopped then
    return
  end
  -- Check for upgrade
  function timeout()
    self:_registerTimeout(function()
      if self.stopped then
        return
      end
      self:_emit()
      timeout()
    end)
  end
  self.timeout = self:calcTimeout()
  logging.debugf('Using Upgrade Timeout %ums', self.timeout)
  self._timer = timer.setTimeout(self.timeout, timeout)
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
