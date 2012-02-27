local fs = require('fs')
local timer = require('timer')
local table = require('table')
local os = require('os')
local Emitter = require('core').Emitter
local async = require('async')

local StateScanner = Emitter:extend()
local LINES_PER_STATE = 4

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

function StateScanner:initialize(stateFile)
  self._stateFile = stateFile
  self._header = {}
end

function StateScanner:start()
  
end

function StateScanner:scanStates()
  local preceeded = {}
  local stream = fs.createReadStream(self._stateFile)
  local scanAt = os.time()
  local version
  local headerDone = false
  local headerLine = 1
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
          self:emit('check_needs_run', preceeded)
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

local exports = {}
exports.StateScanner = StateScanner
return exports