local los = require('los')
local fs = require('fs')
local path = require('path')

local get_static

local load_fixtures = function(dir, is_json)
  local finder = is_json and '(.*)' or '(.*).json'
  -- Convert the \ to / so path.posix works
  if los.type() == 'win32' then
    dir = dir:gsub("\\", "/")
  end
  local fixtures = {}
  local files = fs.readdirSync(dir)
  for _, v in ipairs(files) do
    local filePath = path.join(dir, v)
    if fs.statSync(filePath).type == 'file' then
      local fixture = fs.readFileSync(filePath)
      if is_json then
        fixture = fixture:gsub("\n", " ")
      end
      fixtures[v] = fixture
    end
  end
  return fixtures
end

local base = path.join('static', 'tests', 'protocol')

exports = load_fixtures(base, true)
exports['invalid-version'] = load_fixtures(path.join(base, 'invalid-version'), true)
exports['invalid-process-version'] = load_fixtures(path.join(base, 'invalid-process-version'), true)
exports['invalid-bundle-version'] = load_fixtures(path.join(base, 'invalid-bundle-version'), true)
exports['rate-limiting'] = load_fixtures(path.join(base, 'rate-limiting'), true)
exports['custom_plugins'] = load_fixtures(path.join('static','tests', 'custom_plugins'))
exports['checks'] = load_fixtures(path.join('static','tests', 'checks'))
exports['upgrade'] = load_fixtures(path.join('static','tests', 'upgrade'))

return exports
