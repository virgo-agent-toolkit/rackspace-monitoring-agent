local fs = require('fs')
local table = require('table')
local timer = require('timer')
local string = require('string')
local path = require('path')
local os = require('os')

local async = require('async')

local helper = require('../helper')
local fixtures = require('../fixtures')
local constants = require('constants')
local Endpoint = require('../../default/endpoint').Endpoint
local CrashReporter = require('../../default/crashreport').CrashReporter

local exports = {}
local child

local function start_server(callback)
  local data = ''
  child = helper.runner('server_fixture_blocking')
  child.stderr:on('data', function(d)
    if callback then
      callback(d)
      callback = nil
    end
  end)
  child.stdout:on('data', function(chunk)
    data = data .. chunk
    if data:find('TLS fixture server listening on port 50061') and callback then
      if callback then
        callback()
        callback = nil
      end
    end
  end)
end

local function stop_server(callback)
  if child then
    child:kill(constants.SIGUSR1) -- USR1
    child = nil
  end
  if callback then
    callback()
  end
end

process:on('exit', function()
  stop_server()
end)

exports['test_makes_dump'] = function(test, asserts)

  local options = {
    datacenter = 'test',
    stateDirectory = './tests',
    host = "127.0.0.1",
    port = 50061,
    tls = { rejectUnauthorized = false }
  }

  local dump_dir
  if os.type() == 'win32' then
    dump_dir = 'c:/Temp'
  else
    dump_dir = "/tmp"
  end

  local dump_file = 'rackspace-monitoring-agent-crash-report-unit-test.dmp'
  local dump_path = path.join(dump_dir, dump_file)

  async.series({
    function(callback)
      fs.writeFile(dump_path, "harro\n", callback)
    end,
    start_server,
    function(callback)
      local endpoints = {Endpoint:new(options.host, options.port)}
      local reporter = CrashReporter:new("1.0", "1.0", "test", dump_dir, endpoints)
      reporter:submit(callback)
    end,
    stop_server,
    function(callback)
      fs.exists(dump_path, function(err, res)
        if err then return callback(err) end
        asserts.ok(res==false, 'dump not unlinked')
        callback()
      end)
    end
  }, function(err)
    asserts.ok(err==nil, tostring(err))
    test.done()
  end)
end

return exports
