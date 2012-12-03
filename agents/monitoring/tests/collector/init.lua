--[[
Copyright 2012 Rackspace

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

local http = require('http')
local JSON = require('json')
local os = require('os')
local childprocess = require('childprocess')

local async = require('async')
local LineEmitter = require('line-emitter').LineEmitter

local run = require('monitoring/collector').run
local request = require('monitoring/collector/http/utils').request
local setTimeout = require('timer').setTimeout
local misc = require('monitoring/default/util/misc')

local exports = {}

local function testForTraceroute(callback)
  local tr = childprocess.spawn('traceroute')
  local stderr = ""
  local exit_code = nil

  callback = misc.fireOnce(callback)

  -- true if we take this long before hitting stderr or stdout
  local function callTrueLater()
    setTimeout(300, callback, true)
  end

  tr.stdout:on('data', callTrueLater)

  tr.stderr:on('data', function(d)
    stderr = stderr .. d
    if stderr == "execvp(): No such file or directory\n" then
      return callback(false)
    end
    -- normally exit fires before stderr
    if exit_code then
      return callback(true)
    end
  end)

  -- no error message makes it to the Error:new() .. have to wait for stderr :(
  tr:on('error', callTrueLater)

  tr:on('exit', function(code)
    exit_code = code
    if exit_code == 0 then
      return callback(true)
    end

    -- most likely we couldn't find it
    if exit_code == 127 then
      return callback(false)
    end

    callTrueLater()

  end)

end

exports['test_traceroute'] = function(test, asserts)
  local collector

  local series = {
    function(callback)
      collector = run({p = 7889, h = '127.0.0.1'})
      setTimeout(500, callback)
    end,

    function(callback)
      -- Test invalid route #1
      request('http://127.0.0.1:7889/inexistent', 'GET', nil, nil, {parseResponse = true}, function(err, res)
        asserts.ok(not err)
        asserts.equals(res.status_code, 404)
        asserts.dequals(res.body, {error = 'Path "/inexistent" not found'})
        callback()
      end)
    end,

    function(callback)
      -- Test invalid route #2
      request('http://127.0.0.1:7889/v1.0/traceroute11111', 'GET', nil, nil, {parseResponse = true}, function(err, res)
        asserts.ok(not err)
        asserts.equals(res.status_code, 404)
        asserts.dequals(res.body, {error = 'Path "/v1.0/traceroute11111" not found'})
        callback()
      end)
    end,


    function(callback)
      -- Test missing target argument
      request('http://127.0.0.1:7889/v1.0/traceroute', 'GET', nil, nil, {parseResponse = true}, function(err, res)
        asserts.ok(not err)
        asserts.equals(res.status_code, 400)
        asserts.dequals(res.body, {error = 'Missing a required "target" argument'})
        callback()
      end)
    end,

    function(callback)
      -- Test traceroute
      request('http://127.0.0.1:7889/v1.0/traceroute?target=127.0.0.1', 'GET', nil, nil, {parseResponse = true}, function(err, res)
        asserts.ok(not err)
        asserts.equals(res.status_code, 200)
        asserts.dequals(#res.body, 1)
        asserts.dequals(res.body[1]['number'], 1)
        asserts.dequals(res.body[1]['ip'], '127.0.0.1')
        asserts.dequals(#res.body[1]['rtts'], 3)
        callback()
      end)
    end,

    function(callback)
      -- Test streaming response
      local le = LineEmitter:new()
      local emittedLines = 0

      le:on('data', function(line)
        local parsed
        emittedLines = emittedLines + 1

        if emittedLines == 1 then
          parsed = JSON.parse(line)
          asserts.dequals(parsed['number'], 1)
          asserts.dequals(parsed['ip'], '127.0.0.1')
          asserts.dequals(#parsed['rtts'], 3)
        end
      end)

      local client = http.request({
        host = '127.0.0.1',
        port = 7889,
        path = '/v1.0/traceroute?target=127.0.0.1&streaming=1'
      },

      function (res)
        res:on('data', function (chunk)
          chunk = chunk and chunk or ''
          le:write(chunk)
        end)
        res:on('end', function()
          asserts.equals(emittedLines, 1)
          res:destroy()
          callback()
        end)
      end)

      client:done()
    end
  }

  testForTraceroute(function(support)
    if not support then
      print('\nWARNING: no traceroute found')
      return test.done()
    end

    async.series(series, function()
      collector:stop()
      test.done()
    end)
  end)

end

return exports
