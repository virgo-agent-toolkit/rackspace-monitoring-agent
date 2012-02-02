local path = require('path')
local fs = require('fs')

local exports = {}

function exports.mkdirp(lpath, mode, callback)
  lpath = path.resolve('', lpath)
  fs.mkdir(lpath, mode, function(err)
    if not err then
      callback()
      return
    end
    if err.code == 'ENOENT' then
      exports.mkdirp(path.dirname(lpath), mode, function(err)
        if err then
          callback(err)
        else
          exports.mkdirp(lpath, mode, callback)
        end
      end)
    else
      callback(err)
    end
  end)
end

return exports
