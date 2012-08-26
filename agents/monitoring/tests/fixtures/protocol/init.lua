local path = require('path')
local fs = require('fs')
local string = require('string')
local JSON = require('json')

local fixtures = nil

local strip_newlines = function(str)
  return str:gsub("\n", " ")
end

local load_fixtures = function(dir)
  local fixtures = {}
  local files = fs.readdirSync(dir)

  for i, v in ipairs(files) do
    local _, _, name = string.find(v, '(.*).json')
    if name ~= nil then
      local json = fs.readFileSync(path.join(dir, v))
      json = strip_newlines(json)
      fixtures[name] = json
    end
  end

  return fixtures
end

local base = path.join('agents', 'monitoring', 'tests', 'fixtures', 'protocol')

fixtures = load_fixtures(base)
fixtures['invalid-version'] = load_fixtures(path.join(base, 'invalid-version'))
fixtures['rate-limiting'] = load_fixtures(path.join(base, 'rate-limiting'))

fixtures.prepareJson = function(msg)
  local data = JSON.stringify(msg)
  return strip_newlines(data)
end

return fixtures
