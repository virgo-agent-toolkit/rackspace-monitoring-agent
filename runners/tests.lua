local tap = require("tap")
local uv = require('uv')

local req = uv.fs_scandir("tests")

repeat
  local ent = uv.fs_scandir_next(req)

  if not ent then
    -- run the tests!
    tap(true)
  end
  local match = string.match(ent.name, "^test%-(.*).lua$")
  if match then
    local path = "./tests/test-" .. match
    tap(match)
    require(path)
  end
until not ent
