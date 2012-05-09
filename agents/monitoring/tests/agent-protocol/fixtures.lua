local fs = require('fs')
local string = require('string')

local fixtures = {}

local strip_newlines = function(str)
  return str:gsub("\n", " ")
end

fixture_dir = './agents/monitoring/tests/agent-protocol/fixtures/'
files = fs.readdirSync(fixture_dir)

for i, v in ipairs(files) do
  local _, _, name = string.find(v, '(.*).json')
  local json = fs.readFileSync(fixture_dir .. v)
  json = strip_newlines(json)
  fixtures[name] = json
end

return fixtures
