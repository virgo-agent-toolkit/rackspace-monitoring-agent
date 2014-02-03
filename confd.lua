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
local Filler = require('/util/filler')

local Confd = Object:extend()

--A version of forEach that passes key and value to an iterator
async.forEachTable = function(tab, iterator, callback)
  local key, value, count, completed
  count = 0
  completed = 0
  -- yuck
  for key, value in pairs(tab) do
    count = count + 1
  end
  if count == 0 then
    return callback()
  end
  for key, value in pairs(tab) do
    iterator(key, value, function(err)
      if err then
        local cb = callback
        callback = function() end
        return cb(err)
      end
      completed = completed + 1
      if completed == count then
        return callback()
      end
    end)
  end
end

-- Confd Object Init
function Confd:initialize(confd_dir, state_dir)
  self.dir = confd_dir or virgo_paths.get(virgo_paths.VIRGO_PATH_CONFD_DIR)
  self.hash_file = path.join(state_dir, "confd_hashes.json")
  self.files = {}
  self.logger = loggingUtil.makeLogger('Confd')
  self.constants = {ERROR='ERROR', UNCHANGED='Unchanged', NEW='New', CHANGED='Changed', DELETED='Deleted'}
  self.db_list_order = {'check', 'alarm'}
end

-- Setup the Confd Object, reading files into list
function Confd:setup(callback)
  async.series(
    {
      function(callback)
        self:_getFileList(callback)
      end,
      function(callback)
        self:_readFiles(callback)
      end,
    },
    function(err)
      if err then
        if err.logtype == nil then
          err.logtype = logging.ERROR
        end
        if err.message == nil or err.message == '' then
          err.message = 'unknown error'
        end
        self.logger(err.logtype, fmt("Setup: %s", err.message))
      end
    end
  )

  callback()
end

-- Get the file list
function Confd:getFiles()
  return self.files
end

-- Build the file list
function Confd:_getFileList(callback)
  self.logger(logging.INFO, fmt('reading files in %s', self.dir))
  fs.readdir(self.dir, function(err, files)
    local _, fil
    local count = 0
    if err then
      self.logger(logging.ERROR, fmt('error reading dir %s, %s', self.dir, err.message))
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

-- Read/Parse files into the list
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
        self.logger(logging.ERROR, fmt('error reading file %s, %s', fn, err))
      else
        local status, result = pcall(JSON.parse, data)
        if not status or type(result) == 'string' and result:find('parse error: ') then
          -- parse fail
          self.files[fil].status = self.constants.ERROR
          self.logger(logging.ERROR, fmt('error parsing status:%s, result:%s', status, result))
        else
          self.files[fil].data = result
          local d = crypto.digest.new("sha256")
          d:update(data)
          local hash = d:final()
          self.files[fil].hash = hash

          -- setup meta data with hash and file name
          if not self.files[fil].data.params.metadata then
            self.files[fil].data.params.metadata = {}
          end
          self.files[fil].data.params.metadata.confd_hash = hash
          self.files[fil].data.params.metadata.confd_name = fil

          p("Read File Debugging", fil, self.files[fil].data)
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

-- Mark changed files based on data from the AEP
function Confd:_markChangedFiles(callback)
  local type, objs
  for type, objs in pairs(self.filler:getRetrievedData()) do
    local _, obj
    for _, obj in ipairs(objs) do
      p("File Change Debugging", type, _, obj)
      if obj.metadata and obj.metadata.confd_hash and obj.metadata.confd_name then
        -- object confd created
        local fil = obj.metadata.confd_name
        local hash = obj.metadata.confd_hash

        if not self.files[fil] then
          self.files[fil] = {
            status = self.constants.DELETED,
            data = { type = type }
          }
        else
          if hash ~= self.files[fil].hash then
            if self.files[fil].status ~= self.constants.ERROR then
              self.files[fil].status = self.constants.CHANGED
            end
          else
            self.files[fil].status = self.constants.UNCHANGED
          end
        end

        -- store the server id with the file
        self.files[fil].id = obj.id

        self.logger(logging.INFO, fmt('%s is marked as %s', fil, self.files[fil].status))
      else
        --object not confd created
      end
    end
  end

  callback()
end

-- Run the Confd Operations, non-blocking
function Confd:run(conn, entity, callback)
  self.filler = Filler:new(conn, entity, self.db_list_order)
  self.filler:on("end", function()
    async.series(
      {
        function(callback)
          self:_markChangedFiles(callback)
        end,
        function(callback)
          self:_syncObjects(conn, entity, callback)
        end
      },
      function(err)
        if err then
          if type(err) == 'string' then
            local message = err
            err = { message = message }
          end
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
  end)

  -- Start Gathering Data fron the AEP and Syncing, non-blocking
  self.filler:start()

  callback()
end

-- Sync all objects of a named type in parallel
function Confd:_syncObjectsOfType(conn, entity, now_obj_type, callback)
  local db_map = {
    check = 'syncCheck',
    alarm = 'syncAlarm',
    notification = 'syncNotification',
    notification_plan = 'syncNotificationPlan'
  }

  async.forEachTable(
    self.files,
    function(fil, obj, callback)
      if obj.data and now_obj_type == obj.data.type then
        self.logger(logging.INFO, fmt('starting object sync: %s, %s', now_obj_type, fil))
        xpcall( function()
          local mappedFunc = self[db_map[now_obj_type]]
          mappedFunc(self, conn, entity, obj,
            function(err)
              if (err) then
                self.logger(logging.ERROR,
                  fmt('error syncing objects (mappedFunc) of type: %s, %s with %s', now_obj_type, fil, err))
              else
                obj.handled = true
                self.logger(logging.INFO, fmt('marked as handled for object sync: %s, %s as %s', now_obj_type, fil, obj.status))
              end
              callback()
            end) -- mappedFunc
        end,
        function(err)
          if (err) then
            self.logger(logging.ERROR,
              fmt('error syncing objects (xpcall) of type: %s, %s with %s', now_obj_type, fil, err))
          end
          callback()
        end) -- xpcall
      else
        callback()
      end
    end,
    function(err)
      self.logger(logging.INFO, fmt('finished all objects sync type: %s', now_obj_type))
      if (err) then
        self.logger(logging.ERROR,
          fmt('error syncing objects (foreach) of type: %s with %s', now_obj_type, err))
      end
      callback()
    end) -- foreach
end

-- Sync Each Type of Object
function Confd:_syncObjects(conn, entity, callback)
  async.series(
    {
      function(callback)
        async.forEachSeries(
          self.db_list_order,
          function(now_obj_type, callback)
            self.logger(logging.INFO, fmt('syncing objects marked as: %s', now_obj_type))
            self:_syncObjectsOfType(conn, entity, now_obj_type, callback)
          end,
          callback)
      end,
      function(callback)
        self.logger(logging.INFO, 'sync complete')
        for fil, obj in pairs(self.files) do
          p("Sync Results Debugging", fil, obj)
          if not obj.handled then
            self.logger(logging.WARNING, fmt('object unhandled: %s', fil))
          end
        end
        callback()
      end
    },
    callback)
end

-- Check Sync Modes
function Confd:syncCheck(conn, entity, obj, callback)
  local action = {
    [self.constants.NEW] = function()
      conn:dbCreateChecks(entity, obj.data.params, function(err, data)
        if not err and data.result then
          obj.id = data.result.id
        end
        callback()
      end)
    end,
    [self.constants.DELETED] = function()
      conn:dbRemoveChecks(entity, obj.id, function(err)
        if not err then
          obj.id = nil
        end
        callback()
      end)
    end,
    [self.constants.CHANGED] = function()
      conn:dbUpdateChecks(entity, obj.id, obj.data.params, function(err)
        callback()
      end)
    end
  }

  if action[obj.status] then
    action[obj.status]()
  else
    callback()
  end
end

-- Alarm Sync Modes
function Confd:syncAlarm(conn, entity, obj, callback)
  local action = {
    [self.constants.NEW] = function()
      local checkId = self.files[obj.data.params.check_id_confd_name].id or obj.data.params.check_id
      local params = misc.merge(obj.data.params, { check_id = checkId })
      params.check_id_confd_name = nil  -- remove the name if set to the params sent in
      conn:dbCreateAlarms(entity, params,
        function(err, data)
          if not err and data.result then
            obj.id = data.result.id
          end
          callback()
        end)
    end,
    [self.constants.DELETED] = function()
      conn:dbRemoveAlarms(entity, obj.id, function(err, data)
        if not err then
          obj.id = nil
        end
        callback()
      end)
    end,
    [self.constants.CHANGED] = function()
      local checkId = self.files[obj.data.params.check_id_confd_name].id or obj.data.params.check_id
      local params = misc.merge(obj.data.params, { check_id = checkId })
      params.check_id_confd_name = nil  -- remove the name if set to the params sent in
      conn:dbUpdateAlarms(entity, obj.id, params, function(err)
        callback()
      end)
    end
  }

  if action[obj.status] then
    action[obj.status]()
  else
    callback()
  end
end

function Confd:runOnce(conn, entity, callback)
  if not called then
    called = true
    self:run(conn, entity, callback)
  else
    callback()
  end
end

return Confd
