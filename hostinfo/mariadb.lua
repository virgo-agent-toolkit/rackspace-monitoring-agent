local HostInfo = require('./base').HostInfo
local Mysql = require('./mysql')

--[[ MariaDB ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local mysql = Mysql.Info:new()
  mysql:run(function(err)
    if err then
      self:_pushParams(err)
    else
      self:_pushParams(nil, mysql:serialize())
    end
    callback()
  end)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'MARIADB'
end

exports.Info = Info
