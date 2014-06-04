local fs = require('fs')
local table = require('table')
local timer = require('timer')
local string = require('string')
local path = require('path')
local os = require('os')
local spawn = require('childprocess').spawn

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
      local options = {
        env = { VIRGO_PATH_CRASH = TEST_DIR }
      }
      local child = spawn(process.execPath, {"-o", "-e", "crash", "--production"}, options)
      child:on('exit', function()
        callback()
      end)
    end,
    function(callback)
      local found = false

      -- validate lua stack within dump
      fs.readdir(TEST_DIR, function(err, files)
        if err then
          return callback(err)
        end
        local productName = virgo.default_name:gsub('%-', '%%%-')
        function iter(file, callback)
          -- files we are not looking for
          if string.find(file, productName .. "%-crash%-report-.+.dmp") == nil then
            return callback()
          end
          fs.readFile(path.join(TEST_DIR, file), function(err, data)
            if err then
              return callback(err)
            end
            -- check for lua stack
            found = data:find('__5FY97Y1WBU7GPXCSIRS3T2EEHTSNJ6W183N8FUBFOD5LDWW06ZRBQB8AA8LA8BJD__\n{"stack"') ~= -1
            callback()
          end)
        end
        async.forEach(files, iter, function(err)
          asserts.ok(found == true)
          callback(err)
        end)
      end)
    end,
    function(callback)
      AEP = helper.start_server(callback)
    end,
    function(callback)
      local endpoints = { Endpoint:new(options.host, options.port) }
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
    if AEP then
      AEP:kill(9)
    end
    asserts.ok(err==nil, tostring(err))
    test.done()
  end)
end

if os.type() == "win32" or os.type() == 'Darwin' then
  exports = helper.skip_all(exports, os.type())
end

return exports
