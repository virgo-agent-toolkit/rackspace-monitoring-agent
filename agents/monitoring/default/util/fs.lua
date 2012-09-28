local path = require('path')
local fs = require('fs')
local table = require('table')
local async = require('async')

local exports = {}

-- TODO: move to utils
function reverse ( t )
  local tout = {}

  for i = #t, 1, -1 do
    table.insert(tout, t[i])
  end

  return tout
end

function mkdirp(lpath, mode, callback)
  lpath = path.normalize(lpath)
  local tocreate = {lpath}
  local last = nil
  local current = lpath

  while 1 do
    last = current
    current = path.dirname(current)
    if current == "." then
      break
    end

    table.insert(tocreate, current)

    if last == current then
      break
    end
    if current == nil then
      break
    end
  end

  tocreate = reverse(tocreate)
  async.forEachSeries(tocreate, function (dir, callback)
    fs.mkdir(dir, mode, function(err)
        if not err then
          callback()
          return
        end

        if err.code == "EEXIST" then
          callback()
          return
        end

        fs.stat(dir, function(err2, stats)
          if (err2) then
            -- Okay, so the path didn't exist, but our first mkdir failed, so return the original error.
            callback(err)
            return
          end
          if (stats.is_directory) then
            callback()
            return
          end
          callback(err)
          return
        end)
      end)
  end,
  function(err)
    callback(err)
  end)
end

exports['mkdirp'] = mkdirp
return exports
