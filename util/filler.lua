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

local Emitter = require('core').Emitter
local loggingUtil = require('/util/logging')
local logging = require('logging')
local fmt = require('string').format
local misc = require('/util/misc')
local table = require('table')

local Filler = Emitter:extend()

function Filler:initialize(conn, entity, limit)
  self._conn = conn
  self._entity = entity
  self._limit = limit or 100
  self.logger = loggingUtil.makeLogger('Filler')
  self.db_list_order = { 'check', 'notification_plan', 'alarm', 'notification' }
  self._data = {}
  self.db_list_done = {}
end

function Filler:getRetrievedData()
  return self._data
end

function Filler:start()
  local db_listers = {
    check = function(self, marker, callback)
      self._conn:dbListChecks({entity_id=self._entity}, {limit=self._limit, marker=marker}, callback)
    end,
    alarm = function(self, marker, callback)
      self._conn:dbListAlarms(self._entity, {limit=self._limit, marker=marker}, callback)
    end,
    notification = function(self, marker, callback)
      self._conn:dbListNotification({limit=self._limit, marker=marker}, callback)
    end,
    notification_plan = function(self, marker, callback)
      self._conn:dbListNotificationPlan({limit=self._limit, marker=marker}, callback)
    end
  }

  local _, now_obj_type
  for _, now_obj_type in ipairs(self.db_list_order) do
    self.logger(logging.INFO, fmt('retrieving objects marked as: %s', now_obj_type))
    self._data[now_obj_type] = {}
    xpcall( function()
      self:_list_handler(now_obj_type, db_listers[now_obj_type])
    end, function(err)
      self.logger(logging.ERROR, fmt('retrieving objects error: %s', err))
    end)
  end
end

function Filler:_amidone(obj_type)
  self.db_list_done[obj_type] = true
  local _, now_obj_type
  for _, now_obj_type in ipairs(self.db_list_order) do
    if not self.db_list_done[now_obj_type] then
      return
    end
  end
  self:emit("end")
end

function Filler:_list_handler(obj_type, listfunc)
  self:on(obj_type .. "_end", function()
    self.logger(logging.INFO, fmt('completed retrieving objects marked as: %s', obj_type))
    self:_amidone(obj_type)
  end)
  self:on(obj_type .. "_data", function(err, data)
    --sort out data
    if not err and data.result then
      if data.result.values then
        local _, val
        for _, val in ipairs(data.result.values) do
          table.insert(self._data[obj_type], val)
        end
      end

      --get next data if needed
      local next_key, start
      pcall(function()
        start = data.result.metadata.start
      end)
      pcall(function()
        next_key = data.result.metadata.next_marker.nextKey
      end)

      if next_key or start then
        --get next data from marker on
        listfunc(self, next_key, function (err, data)
          self:emit(obj_type .. "_data", err, data)
        end)
      else
        self:emit(obj_type .. "_end")
      end
    end
  end)
  --start and go
  self:emit(obj_type .. "_data", nil, {result = {metadata = {start = true}}})
end

return Filler