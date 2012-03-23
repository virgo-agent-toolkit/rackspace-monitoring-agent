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
function CheckMeta:initialize(lines)
  self.id = lines[1]
  self.path = lines[2]
  self.state = lines[3]
  self.nextRun = tonumber(lines[4])
end

-- StateScanner is in charge of reading/writing the state file.
function StateScanner:initialize(stateFile)
  self._stateFile = stateFile
  self._header = {}
end

-- Scans the state file and emits 'check_scheduled' events for checks that need to be run.
function StateScanner:scanStates()
  local preceeded = {}
  local stream = fs.createReadStream(self._stateFile)
  local scanAt = os.time()
  local version
  local headerDone = false
  local headerLine = 1
  stream:on('error', function(err)
     p(error)
  end)
  stream:on('data', function(chunk, len)
    local pos = 1
    while true do
      local line
      local index = chunk:find('\n', pos)
      if index then
        line = trim(chunk:sub(pos, index))
        pos = index + 1
      else
        line = chunk:sub(pos)
      end
      if version == nil then
        version = tonumber(trim(line))
      elseif not headerDone then
        headerDone = self:consumeHeaderLine(version, line, headerLine)
        headerLine = headerLine + 1
      elseif line:find('#', 1) ~= 1 then
        table.insert(preceeded, #preceeded + 1, line)
      end
      if #preceeded == LINES_PER_STATE then
        -- todo: if state is correct and time is later than now, emit that puppy.
        preceeded[4] = tonumber(preceeded[4])
        if preceeded[4] <= scanAt then
          self:emit('check_scheduled', CheckMeta:new(preceeded))
        end
        preceeded = {}
      end
      if not index then break end
    end
  end)
end

function StateScanner:consumeHeaderLine(version, line, lineNumber)
  -- a version 1 header is this: version, \n, line count, \n, <line count> lines...
  if version == 1 then
    if lineNumber == 1 then
      self._header.lineCount = tonumber(line)
      return false
    else
      return self._header.lineCount - lineNumber < 0
    end
  end
end

-- dumps all checks to the state file.  totally clobbers the existing file, so watch out yo.
function StateScanner:dumpChecks(checks, callback)
  local fd, fp, tmpFile = nil, 0, self._stateFile..'.tmp'
  local writeLineHelper = function(data)
    return function(callback)
      fs.write(fd, fp, data..'\n', function(err, count)
        fp = fp + count
        callback(err)
      end)
    end
  end
  local writeCheck = function(check, callback)
    async.waterfall({
      writeLineHelper('#'),
      writeLineHelper(check.id),
      writeLineHelper(check.path),
      writeLineHelper(check.state),
      writeLineHelper(check:getNextRun())
    }, function(err)
      callback(err)
    end)
  end
  -- write the initial state file.
  async.waterfall({
    utils.bind(fs.open, tmpFile, 'w', '0644'),
    function(_fd, callback)
      fd = _fd
      callback()
    end,
    writeLineHelper(STATE_FILE_VERSION),
    writeLineHelper(0), -- nothing in the header.
    function(callback)
      async.forEachSeries(checks, writeCheck, function(err)
        callback(err)
      end)
    end,
    function(callback)
      fs.close(fd, callback)
    end,
    utils.bind(fs.rename, tmpFile, self._stateFile)
  }, function(err)
    callback(err)
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
  local checkMap = {}
  -- todo: the check:run closer captures the checks param. thay may end up being a memory liability for cases where
  -- there are many checks.
  for index, check in ipairs(checks) do
    checkMap[check.id] = check
    if self._nextScan == nil then
      self._nextScan = check:getNextRun()
    else
      self._nextScan = math.min(self._nextScan, check:getNextRun())
    end
  end
  self._runCount = 0
  self._scanner = StateScanner:new(stateFile)

  -- serialize all checks. when that is done, create a listener that decides what to when the scanner determines a
  -- check needs to be run.
  self._scanner:dumpChecks(checks, function()
    self._scanner:on('check_scheduled', function(checkMeta)
      -- run the check.
      -- todo: need a process of determining at this point if a check SHOULD NOT be run.
      local check = checkMap[checkMeta.id]
      check:run(function(checkResult)
        self._runCount = self._runCount + 1
        self._scanner:dumpChecks(checks, function()
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
    end)
    callback()
  end)
end

-- start scanning.
function Scheduler:start()
  self._scanner:scanStates()
end

local exports = {}
exports.StateScanner = StateScanner
exports.Scheduler = Scheduler
return exports
