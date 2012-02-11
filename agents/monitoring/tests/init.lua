local bourbon = require('bourbon')
local async = require('async')
local fmt = require('string').format

local exports = {}

local function runit(modname, callback)
  local status, mod = pcall(require, modname)
  if status ~= true then
    process.stdout:write(fmt('Error loading test module [%s]: %s\n\n', modname, mod))
    callback(mod)
  end
  process.stdout:write(fmt('Executing test module [%s]\n\n', modname))
  bourbon.run(nil, mod, function(err)
    process.stdout:write('\n')
    callback()
  end)
end

exports.run = function()
  async.forEachSeries({"./tls", "./agent-protocol", "./crypto"}, runit, function(err)
    if err then
      process.exit(1)
    end
  end)
end

return exports
