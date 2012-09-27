local async = require('async')
local fs = require('fs')
local testUtil = require('monitoring/default/util/test')
local path = require('path')
local fmt = require('string').format

local ApacheCheck = require('monitoring/default/check').ApacheCheck

local PORT = 32321
local HOST = '127.0.0.1'

local exports = {}

exports['test_apache'] = function(test, asserts)
  local url = fmt('http://%s:%s/server-status?auto', HOST, PORT)
  local ch = ApacheCheck:new({id='foo', period=30, details={url=url}})
  local server
  local response

  function reqCallback(req, res)
    if not response then
      local filePath = path.join(process.cwd(), 'agents', 'monitoring', 'tests',
                                 'fixtures', 'checks', 'apache_server_status.txt')
      response = fs.readFileSync(filePath)
    end
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
      ch:run(function(result)
        local metrics = result:getMetrics()['none']
        asserts.equal(result:getState(), 'available')
        asserts.equal(metrics['ReqPerSec']['v'], '136.982')
        asserts.equal(metrics['Uptime']['v'], '246417')
        asserts.equal(metrics['Total_Accesses']['v'], '33754723')
        callback()
      end)
    end
  }, function(err)
    if server then
      server:close()
    end
    asserts.equals(err, nil)
    test.done()
  end)
end

return exports
