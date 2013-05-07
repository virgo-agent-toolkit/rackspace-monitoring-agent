local fs = require('fs')
local table = require('table')
local timer = require('timer')
local string = require('string')
local path = require('path')
local os = require('os')

local async = require('async')

local helper = require('../helper')
local fixtures = require('../fixtures')
local Endpoint = require('/endpoint').Endpoint
local CrashReporter = require('/crashreport').CrashReporter

local exports = {}

exports['test_makes_dump'] = function(test, asserts)
  local AEP

  local options = {
    datacenter = 'test',
    stateDirectory = './tests',
    host = "127.0.0.1",
    port = 50061,
    tls = { rejectUnauthorized = false }
  }

  local dump_path = path.join(TEST_DIR, 'rackspace-monitoring-agent-crash-report-unit-test.dmp')

  async.series({
    function(callback)
      fs.writeFile(dump_path, "harro\n", callback)
    end,
    function(callback)
      AEP = helper.start_server(callback)
    end,
    function(callback)
      local endpoints = {Endpoint:new(options.host, options.port)}
      local reporter = CrashReporter:new("1.0", "1.0", "test", TEST_DIR, endpoints)
      reporter:submit(callback)
    end,
    function(callback)
      fs.exists(dump_path, function(err, res)
        if err then return callback(err) end
        asserts.ok(res==false, 'dump not unlinked')
        callback()
      end)
    end
  }, function(err)
    AEP:kill(9)
    asserts.ok(err==nil, tostring(err))
    test.done()
  end)
end

if os.type() == "win32" then
  exports = helper.skip_all(exports, os.type())
end

return exports
