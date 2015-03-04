local tap = require("../tap")
local uv = require('uv')
local path = require('path')

local req = uv.fs_scandir("tests")

repeat
  local ent = uv.fs_scandir_next(req)

  if not ent then
    -- run the tests!
    tap(true)
  end
  local match = string.match(ent.name, "^test%-(.*).lua$")
  if match then
    local file = path.join(uv.cwd(), 'tests', 'test-' .. match)
    tap(match)
    require(file)
  end
until not ent
