local logging = require('logging')


--[[
Create a new logger which is already bound with a message prefix.

prefix - Message prefix.
return New logging function.
--]]
function makeLogger(prefix)
  if not prefix then
    prefix = ''
  end

  return function(level, message)
    return logging.log(level, prefix  .. ' -> ' .. message)
  end
end

local exports = {}
exports.makeLogger = makeLogger
return exports
