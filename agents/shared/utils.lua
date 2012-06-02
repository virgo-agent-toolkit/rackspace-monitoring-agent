local table = require('table')

local exports = {}

function split(str, pattern)
  pattern = pattern or '[^%s]+'
  if pattern:len() == 0 then pattern = '[^%s]+' end
  local parts = {__index = table.insert}
  setmetatable(parts, parts)
  str:gsub(pattern, parts)
  setmetatable(parts, nil)
  parts.__index = nil
  return parts
end

exports.split = split
return exports
