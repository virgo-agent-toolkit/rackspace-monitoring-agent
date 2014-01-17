--[[
Copyright 2013 Rackspace

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

local Object = require('core').Object
local JSON = require('json')
local fs = require('fs')
local path = require('path')
local logging = require('logging')
local loggingUtil = require('/util/logging')
local fmt = require('string').format
local crypto = require('_crypto')
local async = require('async')
local table = require('table')
local misc = require('/util/misc')

local Confd = Object:extend()


function Confd:initialize(confd_dir, state_dir)
  self.dir = confd_dir or virgo_paths.get(virgo_paths.VIRGO_PATH_CONFD_DIR)
  self.hash_file = path.join(state_dir, "confd_hashes.json")
  self.files = {}
  self.last_hashes = {}
  self.logger = loggingUtil.makeLogger('Confd')
  self.constants = {ERROR='ERROR', UNCHANGED='Unchanged', NEW='New', CHANGED='Changed', DELETED='Deleted'}
end


function Confd:run(callback)
  async.waterfall(
    {
      function(callback)
        self:_getFileList(callback)
      end,
      function(callback)
        self:_readFiles(callback)
      end,
      function(callback)
        self:_readLastFileHashes(callback)
      end,
      function(callback)
        self:_markChangedFiles(callback)
      end,
      function(callback)
        self:writeHashes(callback)
      end
    },
    function(err)
      if err then
        if err.logtype == nil then
          err.logtype = logging.ERROR
        end
        if err.message == nil or err.message == '' then
          err.message = 'unknown error'
        end
        self.logger(err.logtype, fmt("FATAL %s", err.message))
      end
    end
  )
  -- Immediately call the callback to not block the main agent startup
  callback()
end


function Confd:getFiles()
  return self.files
end


function Confd:_getFileList(callback)
  self.logger(logging.INFO, fmt('reading files in %s', self.dir))
  fs.readdir(self.dir, function(err, files)
    local _, fil
    local count = 0
    if err then
      self.logger(logging.WARNING, fmt('error reading %s, %s', self.dir, err.message))
    else
      for _, fil in ipairs(files) do
        --only feed .json files to the parser
        if fil:match('.json$') then
          self.files[fil] = {}
          count = count + 1
        end
      end
    end
    self.file_count = count
    callback()
  end)
end


function Confd:_readFiles(callback)
  local _, fil
  local count = 0
  for fil, _ in pairs(self.files) do
    --Read file to the parser
    local fn = path.join(self.dir,fil)
    fs.readFile(fn, function(err, data)
      if err then
        --log error
        self.files[fil].status = self.constants.ERROR
        self.logger(logging.WARNING, fmt('error reading %s, %s', fn, err.message))
      else
        local status, result = pcall(JSON.parse, data)
        if not status or type(result) == 'string' and result:find('parse error: ') then
          -- parse fail
          self.files[fil].status = self.constants.ERROR
          self.logger(logging.WARNING, fmt('error parsing status:%s, result:%s', status, result))
        else
          self.files[fil].data = result
          local d = crypto.digest.new("sha256")
          d:update(data)
          local hash = d:final()
          self.files[fil].hash = hash
          self.files[fil].status = self.constants.NEW
        self.logger(logging.INFO, fmt('successfully read: %s, hashed: %s', fn, hash))
        end
      end
      count = count + 1
      if count == self.file_count then
        callback()
      end
    end)
  end
end


function Confd:_readLastFileHashes(callback)
  self.logger(logging.INFO, fmt('reading hashes from %s', self.hash_file))
  fs.readFile(self.hash_file, function(err, data)
    if err then
      self.logger(logging.WARNING, fmt('error reading %s, %s', self.hash_file, err.message))
    else
      local status, result = pcall(JSON.parse, data)
      if not status or type(result) == 'string' and result:find('parse error: ') then
        self.logger(logging.WARNING, fmt('error parsing hashes:%s, result:%s', status, result))
      else
        self.last_hashes = result
      end
    end
    callback()
  end)
end


function Confd:_markChangedFiles(callback)
  local fil, _
  for fil, _ in pairs(self.last_hashes) do
    if not self.files[fil] then
      self.files[fil] = {}
      self.files[fil].status = self.constants.DELETED
    end
    if self.last_hashes[fil] ~= self.files[fil].hash then
      if self.files[fil].status ~= self.constants.ERROR then
        self.files[fil].status = self.constants.CHANGED
      end
    else
      self.files[fil].status = self.constants.UNCHANGED
    end
    self.logger(logging.INFO, fmt('%s is marked as %s', fil, self.files[fil].status))
  end
  callback()
end


function Confd:writeHashes(callback)
  self.logger(logging.INFO, fmt('writing hashes into %s', self.hash_file))
  local hashes = {}
  local _, fil
  for fil, _ in pairs(self.files) do
    hashes[fil] = self.files[fil].hash
  end
  fs.writeFile(self.hash_file, JSON.stringify(hashes), function(err)
    if err then
      self.logger(logging.WARNING, fmt('error writing hashes: %s', err.message))
    end
    callback()
  end)
end


function Confd:syncObjects(conn, entity, callback)
  local db_map = {
    check = 'syncCheck',
    alarm = 'syncAlarm',
    notification = 'syncNotification',
    notification_plan = 'syncNotificationPlan'
  }

  local db_sync_order = { 'check', 'notification_plan', 'alarm', 'notification' }

  local db_listers = {
    check = 'listChecks',
    alarm = 'listAlarms',
    notification = 'listNotification',
    notification_plan = 'listNotificationPlan'
  }

  function local_callback(err)
    if (err) then
      self.logger(logging.WARNING, fmt('error syncing object: %s', err.message))
    end
  end

  local _, now_obj_type
  for _, now_obj_type in ipairs(db_sync_order) do
    self.logger(logging.INFO, fmt('retrieving objects marked as: %s', now_obj_type))
    xpcall( function()
      local f = self[db_listers[now_obj_type]]
      f(self, conn, entity, function(err, data)
        p(db_listers[now_obj_type], data)
      end)
    end, function(err)
      self.logger(logging.ERROR, fmt('retrieving objects error: %s', err))
    end)

    self.logger(logging.INFO, fmt('syncing objects marked as: %s', now_obj_type))
    local fil, obj
    for fil, obj in pairs(self.files) do
      if obj.data and now_obj_type == obj.data.type then
        xpcall( function()
          p(obj, obj.data.type, db_map[obj.data.type], self[db_map[obj.data.type]])
          local f = self[db_map[obj.data.type]]
          f(self, conn, entity, obj, local_callback)
          obj.handled = true
        end, function(err)
          self.logger(logging.ERROR, fmt('syncing object error: %s', err))
        end)
      end
    end
  end

  for fil, obj in pairs(self.files) do
    if not obj.handled then
      self.logger(logging.ERROR, fmt('object unhandled: %s', fil))
    end
  end

  callback()
end

function Confd:listChecks(conn, entity, callback)
  conn:dbListChecks({entity_id=entity}, function (err, data)
    p("list", data, data.result.values, data.result.metadata)
  end)
end

function Confd:syncCheck(conn, entity, obj, callback)
  local action = {
    [self.constants.NEW] = function()
      conn:dbCreateChecks(entity, obj.data.params, callback)
    end,
    [self.constants.CHANGED] = function()
      callback()
    end
  }

  if action[obj.status] then
    action[obj.status]()
  else
    callback()
  end
end


function Confd:syncObjectsOnce(conn, entity, callback)
  if not called then
    called = true
    self:syncObjects(conn, entity, callback)
  else
    callback()
  end
end

return Confd
