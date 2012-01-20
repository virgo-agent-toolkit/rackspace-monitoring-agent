local bourbon = require('bourbon')
local async = require('async')
local fmt = require('string').format

local exports = {}

local function runit(modname, callback)
  process.stdout:write(fmt('Executing test module [%s]\n\n', modname))
  bourbon.run(nil, require(modname), function(err)
    process.stdout:write('\n')
    callback()
  end)
end

exports.run = function()
  async.forEachSeries({"./agent-protocol"}, runit, function(err) end)
end

return exports
