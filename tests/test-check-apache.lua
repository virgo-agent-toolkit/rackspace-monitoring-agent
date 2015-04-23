local ApacheCheck = require('../check').ApacheCheck

local async = require('async')
local fs = require('fs')
local testUtil = require('virgo/util/test')

require('tap')(function(test)
  test('check apache', function(expect)
    local HOST, PORT = '127.0.0.1', 32500
    local url = string.format('http://%s:%s/server-status?auto', HOST, PORT)
    local ch = ApacheCheck:new({id='foo', period=30, details={url=url}})
    local response = fs.readFileSync('static/tests/checks/apache_server_status.txt')
    local server

    local function reqCallback(req, res)
      res:writeHead(200, {
        ["Content-Type"] = "text/plain",
        ["Content-Length"] = #response
      })
      res:finish(response)
    end

    async.series({
      function(callback)
        testUtil.runTestHTTPServer(PORT, HOST, reqCallback, function(err, _server)
          server = _server
          callback(err)
        end)
      end,
      function(callback)
        local function onResult(result)
          local metrics = result:getMetrics()['none']
          assert(result:getState() == 'available')
          assert(metrics['requests_per_second']['v'] == '136.982')
          assert(metrics['uptime']['v'] == '246417')
          assert(metrics['total_accesses']['v'] == '33754723')
          callback()
        end
        ch:run(expect(onResult))
      end
    }, expect(function(err)
      if server then server:close() end
      assert(not err)
    end))
  end)
end)
