local options = {}
options.version = require('../package').version
options.paths = {}

require('luvit')(function(...)
  require('virgo')(options, function(...)
    local tap = require("tap")
    local uv = require('uv')
    local constants = require('../constants')
    constants:setGlobal('TESTS_ACTIVE', true)
    local req = uv.fs_scandir("tests")
    repeat
      local ent = uv.fs_scandir_next(req)
      if not ent then
        -- run the tests!
        tap(true)
      end
      local match = string.match(ent.name, "^test%-(.*).lua$")
      if match then
        local file = './test-' .. match
        tap(match)
        require(file)
      end
    until not ent
  end)
end)
