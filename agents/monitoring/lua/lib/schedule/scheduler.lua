local fs = require('fs')
local timer = require('timer')
local table = require('table')
local os = require('os')
local fs = require('fs')
local utils = require('utils')
local Emitter = require('core').Emitter
local Error = require('core').Error
local async = require('async')
local math = require('math')

local JSON = require('json')

local logging = require('logging')
local loggingUtil = require('../util/logging')

local fmt = require('string').format

local StateScanner = Emitter:extend()
local Scheduler = Emitter:extend()
local CheckMeta = Emitter:extend()
local LINES_PER_STATE = 4
local STATE_FILE_VERSION = 1

function trim(s)
  local from = s:match("^%s*()")
  return from > #s and "" or s:match(".*%S", from)
end

-- split on commas.
function split(s, transform)
  local fields = {}
  s:gsub('([^,]+)', function(c) fields[#fields + 1] = transform and transform(c) or c end)
  return fields
end

-- CheckMeta holds the pieces of a check that will appear in a state file.
function CheckMeta:initialize(check)
  self.id = check.id
  self.state = check.state
  self.nextRun = check.nextrun
end

-- StateScanner is in charge of reading/writing the state file.
function StateScanner:initialize(stateFile)
  self._stateFile = stateFile
  self._stopped = false
  self._header = {}
end

function StateScanner:stop()
  self._stopped = true
end

-- Scans the state file and emits 'check_scheduled' events for checks that need to be run.
function StateScanner:scanStates()
  local preceeded = {}
  local scanAt = os.time()
  local version
  local writingChecks = false
  local headerDone = false
  local headerLine = 1
  local data = ''
  local stream = fs.createReadStream(self._stateFile)
  stream:on('error', function(err)
    logging.log(logging.ERR, fmt('Error reading statefile %s', err))
  end)
  stream:on('end', function()
    local status, obj = pcall(JSON.parse, data)
    if status then
      if obj.version ~= STATE_FILE_VERSION then
        logging.log(logging.INFO, fmt('Statefile version mismatch %s != %s', obj.version, STATE_FILE_VERSION))
      else
        for _, check in pairs(obj.checks) do
          if check.nextrun <= scanAt then
            self:emit('check_scheduled', CheckMeta:new(check))
          end
        end
      end
    else
      logging.log(logging.ERR, fmt('Could not parse state file'))
    end
  end)
  stream:on('data', function(chunk)
    if self._stopped == true then
      return
    end
    data = data .. chunk
  end)
end

-- dumps all checks to the state file.  totally clobbers the existing file, so watch out yo.
function StateScanner:dumpChecks(checks, callback)
  local serializedObj = {}
  local fd, fp, tmpFile = nil, 0, self._stateFile..'.tmp'

  serializedObj.version = STATE_FILE_VERSION
  serializedObj.checks = {}
  for i, check in ipairs(checks) do
    serializedObj.checks[i] = checks[i]:serialize()
  end

  if self._stopped == true or self._writingChecks == true then
    callback()
    return
  end

  local writeLineHelper = function(data)
    return function(callback)
      fs.write(fd, fp, JSON.stringify(data) .. '\n', function(err, count)
        fp = fp + count
        callback(err)
      end)
    end
  end

  self._writingChecks = true
  -- write the initial state file.
  async.waterfall({
    utils.bind(fs.open, tmpFile, 'w', '0644'),
    function(_fd, callback)
      fd = _fd
      callback()
    end,
    writeLineHelper(serializedObj),
    function(callback)
      fs.fsync(fd, callback)
    end,
    function(callback)
      fs.close(fd, callback)
    end,
    utils.bind(fs.rename, tmpFile, self._stateFile)
  }, function(err)
    if err then
      callback(err)
      return
    end
    self._writingChecks = false
    callback()
  end)
end


-- Scheduler is in charge of determining if a check should be run and then maintaining the state of the checks.
-- stateFile: file to store checks in.
-- checks: a table of BaseCheck
-- callback: function called after the state file is written
function Scheduler:initialize(stateFile, checks, callback)
  -- todo: I can see there might be a need for a constructor that will read all checks from the state file
  -- in that case, the states will be read and then used as pointers to deserialize checks that already exist on the fs.
  self._log = loggingUtil.makeLogger('scheduler')
  self._nextScan = nil
  self._scanTimer = nil
  self._checkMap = {}
  self._checks = checks or {}
  self._runCount = 0
  self._scanner = StateScanner:new(stateFile)
  self._scanner:on('check_scheduled', function(checkMeta)
    -- run the check.
    -- todo: need a process of determining at this point if a check SHOULD NOT be run.
    local check = self._checkMap[checkMeta.id]
    if check ~= nil then
      check:run(function(checkResult)
        self._runCount = self._runCount + 1
        self._scanner:dumpChecks(self._checks, function()
          self._log(logging.INFO, 'checks dumped at '..os.time())
        end)
        -- emit check
        self:emit('check', check, checkResult)
        -- determine when the next scan should be.
        local oldNextScan = self._nextScan
        local now = os.time()
        -- if the _nextScan is in the future, then find the minimum nextScan timeout
        if self._nextScan > now then
          self._nextScan = math.min(self._nextScan, checkResult._nextRun)
        else
          self._nextScan = checkResult._nextRun
        end
        self._log(logging.DEBUG, fmt('Check %s scheduled at %s, current time %s', check.id, self._nextScan, os.time()))
        -- maybe clear timer, set next.
        if oldNextScan ~= self._nextScan then
          if self._scanTimer then
            timer.clearTimer(self._scanTimer)
          end
          local timeout = (self._nextScan - os.time()) * 1000 -- milliseconds
          self._scanTimer = timer.setTimeout(timeout, function()
            self._scanTimer = nil
            self._scanner:scanStates()
          end)
        end
      end)
    end
  end)
  self:rebuild(checks, callback)
end

function Scheduler:stop()
  if self._scanTimer then
    timer.clearTimer(self._scanTimer)
    self._scanTimer = nil
  end
  self._scanner:stop()
end

-- start scanning.
function Scheduler:start()
  self._scanner:scanStates()
end

function Scheduler:numChecks()
  return #self._checks
end

-- We can rebuid it.  We have the technology.  Better.. faster.. stronger..
-- checks: a table of BaseChecks
-- callback: function called after the state file is written
function Scheduler:rebuild(checks, callback)
  local seen = {}
  local newCheckMap = {}
  local altered = {}
  local vis = false;
  -- todo: the check:run closer captures the checks param. thay may end up being a memory liability for cases where
  -- there are many checks.
  for index, check in ipairs(checks) do
    seen[check.id] = true;
    newCheckMap[check.id] = check
    vis = self._checkMap[check.id] == nil
    if vis or self._checkMap[check.id]:toString() ~= check:toString() then
      self._checkMap[check.id] = check
      if ( not vis) then
        altered[check.id] = true;
      else
        self:emit('added', check)
        table.insert(self._checks, check)
      end
      if self._nextScan == nil then
        self._nextScan = check:getNextRun()
      else
        self._nextScan = math.min(self._nextScan, check:getNextRun())
      end
    end
  end
  for index, check in ipairs(self._checks) do
    if altered[check.id] == true then
      self:emit('altered', check)
      self._checks[index] = newCheckMap[check.id]
    end
    if seen[check.id] == nil then
      self:emit('removed', check)
      table.remove(self._checks, index)
    end
  end
  self._checkMap = newCheckMap
  self._scanner:dumpChecks(self._checks, callback)
end

local exports = {}
exports.StateScanner = StateScanner
exports.Scheduler = Scheduler
return exports
