local SubProcCheck = require('./base').SubProcCheck

local MySQLCheck = SubProcCheck:extend()

function MySQLCheck:initialize(params)
  SubProcCheck.initialize(self, 'agent.mysql', params)
end

function MySQLCheck:_runCheckInChild(callback)
  local cr = CheckResult(self, {})

  local mysqlexact = {
    'libmysqlclient_r',
    'libmysqlclient',
  }

  local mysqlpattern = {
    'libmysqlclient_r%.so.*',
    'libmysqlclient_r%.dylib.*',
    'libmysqlclient_r%.dll.*',
    'libmysqlclient%.so.*',
    'libmysqlclient%.dylib.*',
    'libmysqlclient%.dll.*',
  }

  local mysqlpaths = {
    '/usr/lib',
    '/usr/local/lib',
    '/usr/local/mysql/lib',
    '/opt/local/lib',
  }

  local clib = self:_findLibrary(mysqlexact, mysqlpattern, mysqlpaths)
  if clib == nil then
    checkResult:setError('Couldn\'t find libmysqlclient_r')
    callback(cr)
    return
  end

  checkResult:setError('Found mysqlclient, but not implemented')
  callback(cr)
end

local exports = {}
exports.MySQLCheck = MySQLCheck
return exports
