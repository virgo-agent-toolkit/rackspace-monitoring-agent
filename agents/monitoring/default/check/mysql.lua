local SubProcCheck = require('./base').SubProcCheck

local MySQLCheck = SubProcCheck:extend()

function MySQLCheck:initialize(params)
  SubProcCheck.initialize(self, 'agent.mysql', params)
end

function MySQLCheck:run(callback)
  local checkResult = self:_runCheckInChild('mysql', function (checkResult)
    self._lastResult = checkResult
    callback(checkResult)
  end)
end

local exports = {}
exports.MySQLCheck = MySQLCheck
return exports
