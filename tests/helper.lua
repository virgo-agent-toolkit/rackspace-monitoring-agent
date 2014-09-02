#!/usr/bin/env luvit

local spawn = require('childprocess').spawn
local fs = require('fs')
local path = require('path')
local io = require('io')
local json = require('json')

local constants = require('/constants')
local vutils = require('virgo_utils')

local agent

function start_agent()
  local config_path = path.join(TEST_DIR, 'monitoring-agent-localhost.cfg')
  local args = {
    '-o',
    '-s', TEST_DIR,
    '-z', virgo.loaded_zip_path,
    '-c', config_path
  }

  local config = get_static('/static/tests/monitoring-agent-localhost.cfg')
  fs.writeFileSync(config_path, config)

  local agent = spawn(process.execPath, args)

  agent.stderr:on('data', function(d)
    process.stderr:write(d)
  end)
  agent.stdout:on('data', function(d)
    process.stdout:write(d)
  end)
  return agent
end

local child

local function start_server(options, callback)
  local data = ''

  if type(options) == 'function' then
    callback = options
    options = {}
  end

  local pprint = function(d)
    print('[* AEP *]: ' .. d)
  end

  print('starting mock AEP server ...')
  local args = {
    '-o',
    '-s', TEST_DIR,
    '-z', virgo.loaded_zip_path,
    '-e', 'tests/server.lua'
  }
  child = spawn(process.execPath, args, options)
  child.stderr:on('data', function(d)
    pprint('got stderr' .. d)
    callback(d)
  end)
  local fired = false
  child.stdout:on('data', function(chunk)
    if not fired then
      data = data .. chunk
      if data:find('TLS fixture server listening on port 50061') then
        callback()
        fired = true
      end
    end
  end)
  return child
end

local function at_exit(child)
  pcall(function()
    if not child then return end
    child:kill(9)
  end)

  pcall(function()
    if not agent then return end
    agent:kill(9)
  end)
end

process:on('exit', function()
  at_exit(child)
end)

process:on("error", function(e)
  at_exit(child)
end)

-- This will skip all the functions in an export list but still be able to call them individually
local function skip_all(exports, reason)
  for i,v in pairs(exports) do
    p("Setting a skip " .. i .. " for " .. reason)
    exports[i] = function(test, asserts)
      test.skip("Skipping " .. i .. " for " .. reason)
    end
  end
  return exports
end

local test_configs = {}
if process.env['TEST_CFG_DATA_FILE'] then
  local f = io.open(process.env['TEST_CFG_DATA_FILE'], "r")
  if f ~= nil then
    local content = f:read("*all")
    f:close()
    test_configs = json.parse(content)
  end
end

if not virgo then
  -- parse argv and stuff here
  return
end

local exports = {}
exports.runner = runner
exports.start_server = start_server
exports.skip_all = skip_all
exports.start_agent = start_agent
exports.test_configs = test_configs
return exports
