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

local BaseCheck = require('../base').BaseCheck
local CheckResult = require('../base').CheckResult
local spawn = require('childprocess').spawn
local fireOnce = require('../../util/misc').fireOnce
local parseCSVLine = require('../../util/misc').parseCSVLine
local table = require('table')
local string = require('string')
local os = require('os')

local function lines(str)
  local t = {}
  local function helper(line)
    table.insert(t, line)
    return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

local WindowsPowershellCmdletCheck = BaseCheck:extend()

function WindowsPowershellCmdletCheck:initialize(checkType, powershell_cmd, params)
  self._powershell_cmd = powershell_cmd
  BaseCheck.initialize(self, checkType, params)
end

function WindowsPowershellCmdletCheck:getPowershellCmd()
  return self._powershell_cmd
end

--Requires inherited classes to define handle_entry(entry) to return a metric.
-- See entry_handlers.lua   

function WindowsPowershellCmdletCheck:run(callback)
  -- Set up
  local callback = fireOnce(callback)
  local checkResult = CheckResult:new(self, {})
  local block_data = ''

  if os.type() ~= 'win32' then
    checkResult:setStatus("err " .. self.getType() .. " available only on Windows platforms")

    -- Return Result
    self._lastResult = checkResult
    callback(checkResult)
    return
  end

  -- Perform Check
  local options = {}
  local child = spawn('powershell.exe', {self:getPowershellCmd()}, options)
  child.stdin:close() -- NEEDED for Powershell 2.0 to exit
  child.stdout:on('data', function(chunk)
    -- aggregate the output
    block_data = block_data .. chunk
  end)
  child:on('exit', function(exit_code)
    -- Build Dataset from Block Data
    local data_lines = lines(block_data)
    local count = 0
    local headings = {}
    for x, line in pairs(data_lines) do
      if string.sub(line,1,1) ~= '#' then
        count = count + 1
        if count == 1 then
          local temp = parseCSVLine(line)
          local i = 0
          -- Map headings to indexes
          for x, heading in pairs(temp) do
            i = i + 1
            headings[heading] = i
          end
        else
          -- Parse Data, coverting to numbers when needed
          local entry_array = parseCSVLine(line)
          local entry = {}
          for field, i in pairs(headings) do
            entry[field] = entry_array[i]
          end

          local metric = self:handle_entry(entry)
          if metric then
            checkResult:addMetric(metric.Name, metric.Dimension, metric.Type, metric.Value, metric.Unit)
          end
        end
      end
    end

    -- Return Result
    self._lastResult = checkResult
    callback(checkResult)
  end)
  child:on('error', function(err)
    checkResult:setStatus("err " .. err)

    -- Return Result
    self._lastResult = checkResult
    callback(checkResult)
  end)
end


local exports = {}
exports.WindowsPowershellCmdletCheck = WindowsPowershellCmdletCheck
return exports
