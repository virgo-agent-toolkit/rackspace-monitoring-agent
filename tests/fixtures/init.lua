local os = require('os')
local path = require('path')
local path_base = require('path_base')
local string = require('string')

local statics = require('/lua_modules').statics

local load_fixtures = function(dir, is_json)
  -- Convert the \ to / so path.posix works
  if os.type() == 'win32' then
    dir = dir:gsub("\\", "/")
  end

  if is_json then
    finder = '(.*).json'
  else
    finder = '(.*)'
  end

  local fixtures = {}

  for i,v in ipairs(statics) do
    if path_base.posix:dirname(v) == dir then
      local _, _, name = path_base.posix:basename(v):find(finder)
      if name ~= nil then
        local fixture = get_static(v)
        if is_json then
          fixture = fixture:gsub("\n", " ")
        end
        fixtures[name] =fixture
      end
    end
  end
  return fixtures
end

local base = path.join('static','tests','protocol')

exports = load_fixtures(base, true)
exports['invalid-version'] = load_fixtures(path.join(base, 'invalid-version'), true)
exports['invalid-process-version'] = load_fixtures(path.join(base, 'invalid-process-version'), true)
exports['invalid-bundle-version'] = load_fixtures(path.join(base, 'invalid-bundle-version'), true)
exports['rate-limiting'] = load_fixtures(path.join(base, 'rate-limiting'), true)
exports['custom_plugins'] = load_fixtures(path.join('static','tests', 'custom_plugins'))
exports['checks'] = load_fixtures(path.join('static','tests', 'checks'))
return exports
