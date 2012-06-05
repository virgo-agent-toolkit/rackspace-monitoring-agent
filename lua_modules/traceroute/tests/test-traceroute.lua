local Emitter = require('core').Emitter
local childprocess = require('childprocess')
local fs = require('fs')
local setTimeout = require('timer').setTimeout

local Traceroute = require('../lib/traceroute').Traceroute
local utils = require('../lib/utils')

local exports = {}

-- Mock childprocess
function getEmitter(filePath, returnError)
  local returnError = returnError or false
  local data = fs.readFileSync(filePath)

  function get()
    local emitter = Emitter:extend()

    local split = utils.split(data, '[^\n]+')
    local util = require('utils')

    emitter.stdout = Emitter:new()
    emitter.stderr = Emitter:new()

    setTimeout(500, function()
      for index, line in ipairs(split) do
        if not returnError then
          emitter.stdout:emit('data', line .. '\n')
        else
          emitter.stderr:emit('data', line .. '\n')
        end
      end

      if not returnError then
        emitter:emit('exit', 0)
      else
        emitter:emit('exit', 1)
      end
    end)

    return emitter
  end

  return get
end

exports.getEmitter = getEmitter

exports['test_traceroute_dont_resolve_ips'] = function(test, asserts)
  local hopCount = 0

  local tr = Traceroute:new('www.arnes.si', {resolveIps = false})
  Traceroute._spawn = exports.getEmitter('./tests/fixtures/output_without_hostnames.txt')
  tr:traceroute()

  tr:on('hop', function(hop)
    hopCount = hopCount + 1

    if hopCount == 1 then
      asserts.equals(hop['ip'], '192.168.1.1')
      asserts.dequals(hop['rtts'], {0.496, 0.925, 1.138})
    end
  end)

  tr:on('end', function()
    asserts.equals(hopCount, 22)
    test.done()
  end)
end

exports['test_traceroute_resolve_ips'] = function(test, asserts)
  local hopCount = 0

  local tr = Traceroute:new('www.arnes.si', {resolveIps = true})
  Traceroute._spawn = exports.getEmitter('./tests/fixtures/normal_output.txt')
  tr:traceroute()

  tr:on('hop', function(hop)
    hopCount = hopCount + 1

    if hopCount == 3 then
      asserts.equals(hop['host'], 'te-4-1-ur01.sffolsom.ca.sfba.comcast.net')
      asserts.equals(hop['ip'], '68.85.100.121')
      asserts.dequals(hop['rtts'], {16.848, 16.929, nil})
    end
  end)

  tr:on('end', function()
    asserts.equals(hopCount, 22)
    test.done()
  end)
end

exports['test_traceroute_error_invalid_hostname'] = function(test, asserts)
  local hopCount = 0
  local emittedError = false
  local tr = Traceroute:new('arnes.si', {resolveIps = true})
  Traceroute._spawn = exports.getEmitter('./tests/fixtures/error_invalid_hostname.txt', true)
  tr:traceroute()

  tr:on('hop', function(hop)
    hopCount = hopCount + 1
  end)

  tr:on('error', function(err)
    emittedError = true
    asserts.equals(hopCount, 0)
    asserts.ok(err.message:find('Name or service not known'))
    test.done()
  end)
end

return exports
