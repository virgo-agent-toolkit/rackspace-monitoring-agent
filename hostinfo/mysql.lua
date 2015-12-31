local HostInfo = require('./base').HostInfo
local Transform = require('stream').Transform
local misc = require('./misc')
local run = misc.run
local safeMerge = misc.safeMerge
local async = require('async')
--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()

function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
  self._pushed = false
end

local AdminStatusReader = Reader:extend()
function AdminStatusReader:_transform(line, cb)
  line:gsub('%s*(%D+)%:%s(%d+)', function(key, value)
    self:push({[key] = value})
  end)
  cb()
end

local KeyValueReader = Reader:extend()
function KeyValueReader:_transform(line, cb)
  local key, value = line:match('(%S+)[%s\t]?(%S*)')
  self:push({[key] = value or ''})
  cb()
end

local ReplicantUserReader = Reader:extend()
function ReplicantUserReader:_transform(line, cb)
  local key = line:match('(%S+)[%s\t]?(%S*)')
  if not self._pushed then
    if key:match('^repl') then
      self:push('true')
      self._pushed = true
    end
  end
  cb()
end

local ProcsReader = Reader:extend()
function ProcsReader:_transform(line, cb)
  if not line:find('^%*') then
    local key, value = line:match('(%S+)%:%s(.*)')
    if key and value then
      self:push({[key] = value})
    end
  end
  cb()
end

local VersionReader = Reader:extend()
function VersionReader:_transform(line, cb)
  local dataTable = {}
  line:gsub('%S+', function(c) table.insert(dataTable, c) end)
  self:push({
    name = line:find('MariaDB') and 'MariaDB' or 'MySql',
    version = dataTable[3],
    distribution = dataTable[5],
    targetOS = dataTable[7],
    targetArch = dataTable[8]:match('%((%S+)%)')
  })
  cb()
end

-----------------------------------------------------------------------------------------------------------------------
--[[ MySQL ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local outTable, errTable = {}, {}
  local mySqlServerBin = 'mysqld'
  local mySqlBin = 'mysql'
  local mySqlAdminBin = 'mysqladmin'
  local function _merge(data, err, key, cb)
    outTable[key] = outTable[key] or {}
    errTable[key] = errTable[key] or {}
    if err then safeMerge(errTable[key], err) end
    if data and next(data) then safeMerge(outTable[key], data) end
    cb()
  end

  local function _run(cmd, args, Reader, key, cb)
    local out, errs = {}, {}
    local child = run(cmd, args)
    local reader = Reader:new()
    child:pipe(reader)
    reader:on('data', function(data) safeMerge(out, data) end)
    reader:on('error', function(err) safeMerge(errs, err) end)
    reader:once('end', function() _merge(out, errs, key, cb) end)
  end

  local function _runMysql(input, Reader, key, cb)
    _run(mySqlBin, {"-Bse", input}, Reader, key, cb)
  end

  local function finalCb()
    self:_pushParams(errTable, outTable)
    return callback()
  end

  local function getAdminStatus(cb)
    _run(mySqlAdminBin, {'status'}, AdminStatusReader, 'status', cb)
  end

  local function getDbVersionAndName(cb)
    _run(mySqlBin, {'-V'}, VersionReader, 'version', cb)
  end

  local function getVariables(cb)
    _runMysql('show global variables', KeyValueReader, 'mysql_variables', cb)
  end

  local function getStatus(cb)
    _runMysql('show global status', KeyValueReader, 'mysql_status', cb)
  end

  local function getSlaveStatus(cb)
    _runMysql('show slave status', KeyValueReader, 'mysql_slave_status', cb)
  end

  local function getReplicantUser(cb)
    outTable.replication_user = 'false'
    _runMysql('select user, host from mysql.user', ReplicantUserReader, 'replication_user', cb)
  end

  local function getProcs(cb)
    local child = run(mySqlBin, {'-EBe', 'show full processlist'})
    local reader = ProcsReader:new()
    child:pipe(reader)
    local row, rows = {}, {}
    local count = 0
    outTable.processes = {}
    reader:on('data', function(data)
      count = count + 1
      if count == 8 then
        safeMerge(rows, row)
        row = {}
      else
        safeMerge(row, data)
      end
    end)
    reader:on('error', function(err)
      safeMerge(errTable, err)
      return cb()
    end)
    reader:once('end', function()
      _merge(rows, nil, 'processes', cb) end)
  end

  outTable.bin = mySqlServerBin

  async.parallel({
    getDbVersionAndName,
    getAdminStatus,
    getVariables,
    getStatus,
    getSlaveStatus,
    getReplicantUser,
    getProcs
  }, finalCb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'MYSQL'
end

exports.Info = Info
exports.AdminStatusReader = AdminStatusReader
exports.KeyValueReader = KeyValueReader
exports.ReplicantUserReader = ReplicantUserReader
exports.ProcsReader = ProcsReader
exports.VersionReader = VersionReader
