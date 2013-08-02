local async = require('async')
local testUtil = require('/base/util/test')
local fmt = require('string').format

local ApacheCheck = require('/check').ApacheCheck

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
      response = get_static('/static/tests/checks/apache_server_status.txt')
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
        asserts.equal(metrics['requests_per_second']['v'], '136.982')
        asserts.equal(metrics['uptime']['v'], '246417')
        asserts.equal(metrics['total_accesses']['v'], '33754723')
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
