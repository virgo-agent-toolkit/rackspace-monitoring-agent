local fs = require('fs')
local timer = require('timer')
local table = require('table')
local os = require('os')
local Emitter = require('core').Emitter
local async = require('async')

local Scheduler = Emitter:extend()
local LINES_PER_STATE = 4

function trim(s)
  local from = s:match"^%s*()"
  return from > #s and "" or s:match(".*%S", from)
end

function Scheduler:initialize(stateFile)
  self._stateFile = stateFile
end

function Scheduler:start()
  
end

function Scheduler:scanStates()
  local preceeded = {}
  local stream = fs.createReadStream(self._stateFile)
  local scanAt = os.time()
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
      if line:find('#', 1) ~= 1 then
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

local exports = {}
exports.Scheduler = Scheduler
return exports