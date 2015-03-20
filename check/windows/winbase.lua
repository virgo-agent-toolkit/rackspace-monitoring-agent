--[[
Copyright 2015 Rackspace

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
local fireOnce = require('virgo/util/misc').fireOnce
local parseCSVLine = require('virgo/util/misc').parseCSVLine
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

function WindowsPowershellCmdletCheck:initialize(powershell_cmd, params)
  self._powershell_cmd = powershell_cmd
  if params.details and #params.details then
    self._powershell_csv_fixture = params.details.powershell_csv_fixture
  end
  -- Powershell 2.0 carries the screen width to stdio and adds \r\n at the console width
  self.width_needed = 2000
  self.screen_settings = 'if( $Host -and $Host.UI -and $Host.UI.RawUI ) { $rawUI = $Host.UI.RawUI; $oldSize = $rawUI.BufferSize; $typeName = $oldSize.GetType( ).FullName; $newSize = New-Object $typeName (' .. self.width_needed .. ', $oldSize.Height); $rawUI.BufferSize = $newSize ;} ;'
  -- Dump the error when the core command fails
  self.error_output = ' ; if ($virgo_err[0]) { $virgo_err[0] | Select @{name="Name";expression={"__VIRGO_ERROR"}}, @{name="Value";expression={$_.Exception}}, @{name="Type";expression={"string"}} | ConvertTo-CSV }'
  BaseCheck.initialize(self, params)
end

function WindowsPowershellCmdletCheck:getPowershellCmd()
  return self._powershell_cmd
end

function WindowsPowershellCmdletCheck:getPowershellCSVFixture()
  return self._powershell_csv_fixture
end

--Requires inherited classes to define handle_entry(entry) to return a metric.
-- See entry_handlers.lua

function WindowsPowershellCmdletCheck:checkForError(entry)
  local err = nil
  if entry.Name and entry.Name == '__VIRGO_ERROR' then
    err = entry.Value
  end
  return err
end

function WindowsPowershellCmdletCheck:escapeString(s)
  return string.gsub(s, "([$\"'`])", "`%1")
end

function WindowsPowershellCmdletCheck:run(callback)
  -- Set up
  callback = fireOnce(callback)
  local checkResult = CheckResult:new(self, {})
  local block_data = ''

  local function handle_data(exit_code)
    -- Build Dataset from Block Data
    local data_lines = lines(block_data)
    local count = 0
    local headings = {}
    local error = nil
    for x, line in pairs(data_lines) do
      if string.sub(line,1,1) ~= '#' then
        count = count + 1
        if count == 1 then
          local temp = parseCSVLine(line)
          local i = 0
          -- Map headings to indexes
          for _, heading in pairs(temp) do
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

          error = self:checkForError(entry)
          if error then
            break;
          end

          local metric = self:handle_entry(entry)
          if metric then
            checkResult:addMetric(metric.Name, metric.Dimension, metric.Type, metric.Value, metric.Unit)
          end
        end
      end
    end

    if error then
      checkResult:setStatus("err " .. error)
    end

    -- Return Result
    self._lastResult = checkResult
    callback(checkResult)
  end

  if not self:getPowershellCSVFixture() then
    if os.type() ~= 'win32' then
      checkResult:setStatus("err " .. self:getType() .. " available only on Windows platforms")

      -- Return Result
      self._lastResult = checkResult
      callback(checkResult)
      return
    end

    -- Perform Check
    local options = {}
    local wrapper = self.screen_settings .. self:getPowershellCmd() .. self.error_output
    local child = spawn('powershell.exe', {wrapper}, options)
    child.stdin:close() -- NEEDED for Powershell 2.0 to exit
    child.stdout:on('data', function(chunk)
      -- aggregate the output
      block_data = block_data .. chunk
    end)
    child:on('exit', handle_data)
    child:on('error', function(err)
      checkResult:setStatus("err " .. err)

      -- Return Result
      self._lastResult = checkResult
      callback(checkResult)
    end)
  else
    block_data = self:getPowershellCSVFixture()
    handle_data(0)
  end
end

exports.WindowsPowershellCmdletCheck = WindowsPowershellCmdletCheck
