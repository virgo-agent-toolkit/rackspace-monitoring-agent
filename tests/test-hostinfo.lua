--[[
Copyright 2015 Rackspace

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

require('tap')(function(test)

  local hostinfo = require('../hostinfo')
  local fixtures = require('./fixtures')
  local hostinfoFixtureDir = fixtures.hostinfo
  local LineEmitter = require('line-emitter').LineEmitter
  local json = require('json')
  local is_equal = require('virgo/util/underscore').is_equal

  for _, type in pairs(hostinfo.getTypes()) do
    test('test ' .. type, function(expect)
      local info = hostinfo.create(type)
      info:run(expect(function() assert(info._params, 'Params should be an object, was false or nil') end))
    end)
  end
  -- check if all hostinfos call callback at the end
  test('test for bad hostinfo', function(expect)
    local info
    local errMsg = 'this is an error'
    local function onRun()
      assert(info._error:find(errMsg))
    end
    info = hostinfo.create('nil')
    info._run = function()
      error(errMsg)
    end
    info:run(expect(onRun))
  end)

  -- Utility function to run checks
  local function testTemplate(expect, hostinfoName, testFileName, Reader)
    local hostinfo = require('../hostinfo/'..hostinfoName)
    local errTable, outTable = {}, {}
    local reader = hostinfo[Reader]:new()
    local inFixture = LineEmitter:new()
    local outFixture = hostinfoFixtureDir[testFileName..'_out.txt']
    local cb = expect(function()
      local outFixtureTable = json.parse(outFixture)
      assert(is_equal(outFixtureTable, outTable), 'not ok: outFixture and outTable dont match')
      assert(#errTable==0, 'Not ok: errtable is not 0 length')
    end)
    inFixture:pipe(reader)
    reader:on('error', function(err) table.insert(errTable, err) end)
    reader:on('data', function(data) table.insert(outTable, data) end)
    reader:once('end', cb)
    local chunk = hostinfoFixtureDir[testFileName..'_in.txt']
    inFixture:write(chunk)
    inFixture:write()
  end

  -- Some of the hostinfo checks are very similiar and only have one reader so we'll just loop over them
  local hostinfoChecks = {
    'cron',
    'deleted_libs',
    'cve',
    'fstab',
    'ip4routes',
    'ip6routes',
    'ip6tables',
    'iptables',
    'kernel_modules',
    'last_logins',
    'login',
    'pam',
    'passwd',
    'remote_services',
    'sshd',
    'sysctl'
  }

  for _, checkName in pairs(hostinfoChecks) do
    test('Test: ' .. checkName, function(expect)
      testTemplate(expect, checkName, checkName, 'Reader')
    end)
  end

  ---------------------------------------------- Tests for Autoupdates ------------------------------------------------

  test('Test Autoupdates: apt reader enabled', function(expect)
    testTemplate(expect, 'autoupdates', 'autoupdates_apt', 'AptReader')
  end)

  test('Test Autoupdates: yum reader enabled', function(expect)
    testTemplate(expect, 'autoupdates', 'autoupdates_yum', 'YumReader')
  end)

  ----------------------------------------------- Tests for packages --------------------------------------------------

  test('Test Packages: linux reader', function(expect)
    testTemplate(expect, 'packages', 'packages_linux', 'LinuxReader')
  end)

  ----------------------------------------------- Tests for apache2 --------------------------------------------------

  test('Test Apache2: apache output reader', function(expect)
    testTemplate(expect, 'apache2', 'apache2_apacheOut', 'ApacheOutputReader')
  end)

  test('Test Apache2: VhostOutputReader', function(expect)
    testTemplate(expect, 'apache2', 'apache2_VhostOutput', 'VhostOutputReader')
  end)

  test('Test Apache2: VhostConfigReader', function(expect)
    testTemplate(expect, 'apache2', 'apache2_VhostConfig', 'VhostConfigReader')
  end)

  test('Test Apache2: RamPerPreforkChildReader', function(expect)
    testTemplate(expect, 'apache2', 'apache2_RamPerPreforkChild', 'RamPerPreforkChildReader')
  end)

  ----------------------------------------------- Tests for connections ------------------------------------------------

  test('Test Connections: arp reader', function(expect)
    testTemplate(expect, 'connections', 'connections_arp', 'ArpReader')
  end)

  test('Test Connections: netstat reader', function(expect)
    testTemplate(expect, 'connections', 'connections_netstat', 'NetstatReader')
  end)
  ----------------------------------------------- Tests for lsyncd -----------------------------------------------------
  test('Test Lsyncd: LsyncProcReader', function(expect)
    testTemplate(expect, 'lsyncd', 'lsyncd_lsyncproc', 'LsyncProcReader')
  end)

  ----------------------------------------------- Tests for fail2ban ------------------------------------------------
  test('Test Fail2ban: LogfilePathReader', function(expect)
    testTemplate(expect, 'fail2ban', 'fail2ban_logfilepath', 'LogfilePathReader')
  end)

  test('Test Fail2ban: JailsListReader', function(expect)
    testTemplate(expect, 'fail2ban', 'fail2ban_jailslist', 'JailsListReader')
  end)

  test('Test Fail2ban: ActivityLogReader', function(expect)
    testTemplate(expect, 'fail2ban', 'fail2ban_activitylog', 'ActivityLogReader')
  end)

  test('Test Fail2ban: BannedStatsReader', function(expect)
    testTemplate(expect, 'fail2ban', 'fail2ban_bannedstats', 'BannedStatsReader')
  end)

end)
