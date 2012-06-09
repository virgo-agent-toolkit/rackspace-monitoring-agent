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

exports['test_traceroute_route_1'] = function(test, asserts)
  local hopCount = 0
  local splitHops = {}
  local hopNumber = 0

  local tr = Traceroute:new('193.2.1.87', {})
  Traceroute._spawn = exports.getEmitter('./tests/fixtures/output_without_hostnames.txt')
  tr:traceroute()

  tr:on('hop', function(hop)
    hopCount = hopCount + 1
    hopNumber = hop['number']

    if not splitHops[hopNumber] then
      splitHops[hopNumber] = 0
    end

    splitHops[hopNumber] = splitHops[hopNumber] + 1

    if hopCount == 1 then
      asserts.equals(hop['number'], 1)
      asserts.equals(hop['ip'], '192.168.1.1')
      asserts.dequals(hop['rtts'], {0.496, 0.925, 1.138})
    elseif hopCount == 8 then
      asserts.equals(hop['number'], 8)
      asserts.equals(hop['ip'], '154.54.2.165')
      asserts.dequals(hop['rtts'], {46.276})
    elseif hopCount == 9 then
      asserts.equals(hop['number'], 8)
      asserts.equals(hop['ip'], '154.54.5.37')
      asserts.dequals(hop['rtts'], {46.271})
    elseif hopCount == 10 then
      asserts.equals(hop['number'], 8)
      asserts.equals(hop['ip'], '154.54.5.57')
      asserts.dequals(hop['rtts'], {45.894})
    elseif hopNumber == 21 then
      if splitHops[hopNumber] == 1 then
        asserts.equals(hop['number'], 21)
        asserts.equals(hop['ip'], '*')
        asserts.dequals(hop['rtts'], {})
      elseif splitHops[hopNumber] == 2 then
        asserts.equals(hop['number'], 21)
        asserts.equals(hop['ip'], '88.200.7.249')
        asserts.dequals(hop['rtts'], {210.282, 207.316})
      end
    elseif hopNumber == 22 then
      asserts.equals(hop['number'], 22)
      asserts.equals(hop['ip'], '88.200.7.249')
      asserts.dequals(hop['rtts'], {196.908})
    end
  end)

  tr:on('end', function()
    asserts.equals(hopNumber, 22)
    test.done()
  end)
end

exports['test_traceroute_route_2'] = function(test, asserts)
  local hopCount = 0
  local splitHops = {}
  local hopNumber = 0

  local tr = Traceroute:new('184.106.74.174', {})
  Traceroute._spawn = exports.getEmitter('./tests/fixtures/output_split_routes_2.txt')
  tr:traceroute()

  tr:on('hop', function(hop)
    hopCount = hopCount + 1
    hopNumber = hop['number']

    if not splitHops[hopNumber] then
      splitHops[hopNumber] = 0
    end

    splitHops[hopNumber] = splitHops[hopNumber] + 1

    if hopCount == 1 then
      asserts.equals(hop['number'], 1)
      asserts.equals(hop['ip'], '50.56.142.130')
      asserts.dequals(#hop['rtts'], 3)
    elseif hopNumber == 3 then
      if splitHops[hopNumber] == 1 then
        asserts.equals(hop['number'], 3)
        asserts.equals(hop['ip'], '174.143.123.87')
        asserts.dequals(hop['rtts'], {1.115})
      elseif splitHops[hopNumber] == 2 then
        asserts.equals(hop['number'], 3)
        asserts.equals(hop['ip'], '174.143.123.85')
        asserts.dequals(hop['rtts'], {1.517, 1.527})
      end
    end
  end)

  tr:on('end', function()
    asserts.equals(hopNumber, 7)
    test.done()
  end)
end

exports['test_traceroute_route_3'] = function(test, asserts)
  local hopCount = 0
  local splitHops = {}
  local hopNumber = 0

  local tr = Traceroute:new('94.236.68.69', {})
  Traceroute._spawn = exports.getEmitter('./tests/fixtures/output_split_routes_3.txt')
  tr:traceroute()

  tr:on('hop', function(hop)
    hopCount = hopCount + 1
    hopNumber = hop['number']

    if not splitHops[hopNumber] then
      splitHops[hopNumber] = 0
    end

    splitHops[hopNumber] = splitHops[hopNumber] + 1

    if hopNumber == 17 then
      if splitHops[hopNumber] == 1 then
        asserts.equals(hop['number'], 17)
        asserts.equals(hop['ip'], '164.177.137.103')
        asserts.dequals(hop['rtts'], {155.621})
      elseif splitHops[hopNumber] == 2 then
        asserts.equals(hop['number'], 17)
        asserts.equals(hop['ip'], '164.177.137.101')
        asserts.dequals(hop['rtts'], {155.285})
      elseif splitHops[hopNumber] == 3 then
        asserts.equals(hop['number'], 17)
        asserts.equals(hop['ip'], '164.177.137.103')
        asserts.dequals(hop['rtts'], {154.711})
      end
    end
  end)

  tr:on('end', function()
    asserts.equals(hopNumber, 19)
    test.done()
  end)
end

exports['test_traceroute_error_invalid_hostname'] = function(test, asserts)
  local hopCount = 0
  local tr = Traceroute:new('arnes.si', {})
  Traceroute._spawn = exports.getEmitter('./tests/fixtures/error_invalid_hostname.txt', true)
  tr:traceroute()

  tr:on('hop', function(hop)
    hopCount = hopCount + 1
  end)

  tr:on('error', function(err)
    asserts.equals(hopCount, 0)
    asserts.ok(err.message:find('Name or service not known'))
    test.done()
  end)
end

exports['test_traceroute_ipv6'] = function(test, asserts)
  local hopCount = 0
  local splitHops = {}
  local hopNumber = 0

  local tr = Traceroute:new('2607:f8b0:4009:803::1000', {})
  Traceroute._spawn = exports.getEmitter('./tests/fixtures/output_ipv6_split_routes.txt', false)
  tr:traceroute()

  tr:on('hop', function(hop)
    hopCount = hopCount + 1
    hopNumber = hop['number']

    if not splitHops[hopNumber] then
      splitHops[hopNumber] = 0
    end

    splitHops[hopNumber] = splitHops[hopNumber] + 1

    if hopCount == 2 then
        asserts.equals(hop['number'], 2)
        asserts.equals(hop['ip'], '2001:4801:800:c3:601a:2::')
        asserts.dequals(hop['rtts'], {0.974, 1.147, 1.150})
    elseif hopNumber == 3 then
      if splitHops[hopNumber] == 1 then
        asserts.equals(hop['ip'], '2001:4801:800:cb:c3::')
        asserts.dequals(hop['rtts'], {0.766})
      elseif splitHops[hopNumber] == 2 then
        asserts.equals(hop['ip'], '2001:4801:800:ca:c3::')
        asserts.dequals(hop['rtts'], {0.773})
      elseif splitHops[hopNumber] == 3 then
        asserts.equals(hop['ip'], '2001:4801:800:cb:c3::')
        asserts.dequals(hop['rtts'], {0.954})
      end
    end
  end)

  tr:on('end', function(err)
    asserts.equals(hopNumber, 10)
    test.done()
  end)
end

return exports
