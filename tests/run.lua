local options = {}
options.version = require('../package').version
options.paths = {}

require('luvit')(function(...)
  require('virgo')(options, function(...)
    local tap = require("tap")
    local uv = require('uv')
    local constants = require('../constants')
    constants:setGlobal('TESTS_ACTIVE', true)

    local function runAll()
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
    end

    local function runFile(testModule)
      local file = './test-' .. testModule
      tap(testModule)
      require(file)
      tap(true)
    end

    local testModule = process.env['TEST_MODULE']
    if testModule then
      runFile(testModule)
    else
      runAll()
    end
  end)
end)
