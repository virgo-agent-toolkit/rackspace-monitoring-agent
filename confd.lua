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


function Confd:initialize(confd_dir, state_dir)
  self.dir = confd_dir or virgo_paths.get(virgo_paths.VIRGO_PATH_CONFD_DIR)
  self.hash_file = path.join(state_dir, "confd_hashes.json")
  self.files = {}
  self.logger = loggingUtil.makeLogger('Confd')
  self.constants = {ERROR='ERROR', UNCHANGED='Unchanged', NEW='New', CHANGED='Changed', DELETED='Deleted'}
end


function Confd:_logging_callback(err)
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

function Confd:setup(callback)
  async.waterfall(
    {
      function(callback)
        self:_getFileList(callback)
      end,
      function(callback)
        self:_readFiles(callback)
      end,
    },
    self._logging_callback
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

          -- setup meta data with hash and file name
          if not self.files[fil].data.params.metadata then
            self.files[fil].data.params.metadata = {}
          end
          self.files[fil].data.params.metadata.confd_hash = hash
          self.files[fil].data.params.metadata.confd_name = fil

          p(self.files[fil].data)
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


function Confd:_markChangedFiles(callback)
  local type, objs
  for type, objs in pairs(self.filler:getRetrievedData()) do
    local _, obj
    for _, obj in ipairs(objs) do
      p(type, _, obj)
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

        -- store the server obj with the file
        self.files[fil].server_obj = obj

        self.logger(logging.INFO, fmt('%s is marked as %s', fil, self.files[fil].status))
      else
        --object not confd created
      end
    end
  end

  callback()
end


function Confd:run(conn, entity, callback)
  self.filler = Filler:new(conn, entity, 1)
  self.filler:on("end", function()
    async.waterfall(
      {
        function(callback)
          self:_markChangedFiles(callback)
        end,
        function(callback)
          self:_syncObjects(conn, entity, callback)
        end
      },
      self._logging_callback
    )
  end)

  self.filler:start()

  callback()
end


function Confd:_syncObjects(conn, entity, callback)
  local db_map = {
    check = 'syncCheck',
    alarm = 'syncAlarm',
    notification = 'syncNotification',
    notification_plan = 'syncNotificationPlan'
  }

  function local_callback(err)
    if (err) then
      self.logger(logging.WARNING, fmt('error syncing object: %s', err.message))
    end
  end

  local _, now_obj_type
  for _, now_obj_type in ipairs(self.filler:getDbListOrder()) do
    self.logger(logging.INFO, fmt('syncing objects marked as: %s', now_obj_type))
    local fil, obj
    for fil, obj in pairs(self.files) do
      if obj.data and now_obj_type == obj.data.type then
        xpcall( function()
          local f = self[db_map[now_obj_type]]
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

function Confd:syncCheck(conn, entity, obj, callback)
  local action = {
    [self.constants.NEW] = function()
      conn:dbCreateChecks(entity, obj.data.params, callback)
    end,
    [self.constants.DELETED] = function()
      conn:dbRemoveChecks(entity, obj.server_obj.id, callback)
    end,
    [self.constants.CHANGED] = function()
      conn:dbUpdateChecks(entity, obj.server_obj.id, obj.data.params, callback)
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
