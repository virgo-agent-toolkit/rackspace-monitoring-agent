local utils = require('utils')

local Traceroute = require('../lib/traceroute').Traceroute

local tr = Traceroute:new('www.arnes.si')
tr:traceroute()

tr:on('hop', function(hop)
  print('hop')
  print(utils.dump(hop))
end)

tr:on('end', function(hop)
  print('end')
end)

tr:on('error', function(err)
  print('error: ' .. err.message)
end)

