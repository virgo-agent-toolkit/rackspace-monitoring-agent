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
    test('Smoke test for: ' .. type, function(expect)
      local info = hostinfo.create(type)
      local errMsg = 'this is an error'
      local errMsgUnsupported = 'Unsupported operating system for'
      local cb = expect(function()
        local found = info._error:find(errMsg) >= 0 or info._error:find(errMsgUnsupported) >= 0
        assert(found, "Couldn't find error message")
        assert(info._params, 'Params should be an object, was false or nil')
      end)
      info:_pushError(errMsg)
      info:run(cb)
    end)
  end

  -- Utility function to run checks
  local function testTemplate(expect, hostinfoName, testFileName, Reader)
    local hostinfo = require('../hostinfo/'..hostinfoName)
    local errTable, outTable = {}, {}
    local reader = hostinfo[Reader]:new()
    local inFixture = LineEmitter:new()
    local outFixture = hostinfoFixtureDir[testFileName..'_out.txt']
    local cb = expect(function()
      local outFixtureTable = json.parse(outFixture)
      local outTableStr = json.stringify(outTable)
      local errMsg = 'Not ok: outFixture and outTable dont match.\nExpected:'..outFixture..'Got:'..outTableStr
      assert(is_equal(outFixtureTable, outTable), errMsg)
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
    'sysctl',
    'magento',
    'lsyncd',
    'hostname'
  }

  for _, checkName in pairs(hostinfoChecks) do
    test('Unit test for reader in: ' .. checkName, function(expect)
      testTemplate(expect, checkName, checkName, 'Reader')
    end)
  end

  ---------------------------------------------- Tests for Autoupdates ------------------------------------------------

  test('Unit test for Autoupdates: apt reader enabled', function(expect)
    testTemplate(expect, 'autoupdates', 'autoupdates_apt', 'AptReader')
  end)

  test('Unit test for Autoupdates: yum reader enabled', function(expect)
    testTemplate(expect, 'autoupdates', 'autoupdates_yum', 'YumReader')
  end)

  ----------------------------------------------- Tests for packages --------------------------------------------------

  test('Unit test for Packages: linux reader', function(expect)
    testTemplate(expect, 'packages', 'packages_linux', 'LinuxReader')
  end)

  ----------------------------------------------- Tests for apache2 --------------------------------------------------

  test('Unit test for Apache2: apache output reader', function(expect)
    testTemplate(expect, 'apache2', 'apache2_apacheOut', 'ApacheOutputReader')
  end)

  test('Unit test for Apache2: VhostOutputReader', function(expect)
    testTemplate(expect, 'apache2', 'apache2_VhostOutput', 'VhostOutputReader')
  end)

  test('Unit test for Apache2: VhostConfigReader', function(expect)
    testTemplate(expect, 'apache2', 'apache2_VhostConfig', 'VhostConfigReader')
  end)

  test('Unit test for Apache2: RamPerPreforkChildReader', function(expect)
    testTemplate(expect, 'apache2', 'apache2_RamPerPreforkChild', 'RamPerPreforkChildReader')
  end)

  ----------------------------------------------- Tests for connections ------------------------------------------------

  test('Unit test for Connections: arp reader', function(expect)
    testTemplate(expect, 'connections', 'connections_arp', 'ArpReader')
  end)

  test('Unit test for Connections: netstat reader', function(expect)
    testTemplate(expect, 'connections', 'connections_netstat', 'NetstatReader')
  end)

  ----------------------------------------------- Tests for nginx ------------------------------------------------------

  test('Unit test for Nginx: VersionAndConfigureOptionsReader', function(expect)
    testTemplate(expect, 'nginx_config', 'nginx_VersionAndConfigureOptions', 'VersionAndConfigureOptionsReader')
  end)

  test('Unit test for Nginx: ConfArgsReader', function(expect)
    testTemplate(expect, 'nginx_config', 'nginx_ConfArgs', 'ConfArgsReader')
  end)

  test('Unit test for Nginx: ConfFileReader', function(expect)
    testTemplate(expect, 'nginx_config', 'nginx_ConfFile', 'ConfFileReader')
  end)

  test('Unit test for Nginx: VhostReader', function(expect)
    testTemplate(expect, 'nginx_config', 'nginx_Vhost', 'VhostReader')
  end)

  test('Unit test for Nginx: ConfValidOrErrReader', function(expect)
    testTemplate(expect, 'nginx_config', 'nginx_ConfValidOrError', 'ConfValidOrErrReader')
  end)

  ----------------------------------------------- Tests for fail2ban ------------------------------------------------

  test('Unit test for Fail2ban: LogfilePathReader', function(expect)
    testTemplate(expect, 'fail2ban', 'fail2ban_logfilepath', 'LogfilePathReader')
  end)

  test('Unit test for Fail2ban: JailsListReader', function(expect)
    testTemplate(expect, 'fail2ban', 'fail2ban_jailslist', 'JailsListReader')
  end)

  test('Unit test for Fail2ban: ActivityLogReader', function(expect)
    testTemplate(expect, 'fail2ban', 'fail2ban_activitylog', 'ActivityLogReader')
  end)

  test('Unit test for Fail2ban: BannedStatsReader', function(expect)
    testTemplate(expect, 'fail2ban', 'fail2ban_bannedstats', 'BannedStatsReader')
  end)

  ----------------------------------------------- Tests for postfix ---------------------------------------------------

  test('Unit test for Postfix: ProcessReader', function(expect)
    testTemplate(expect, 'postfix', 'postfix_Process', 'ProcessReader')
  end)

  test('Unit test for Postfix: ConfigReader', function(expect)
    testTemplate(expect, 'postfix', 'postfix_Config', 'ConfigReader')
  end)

  ----------------------------------------------- Tests for wordpress --------------------------------------------------

  test('Unit test for Wordpress: VersionReader', function(expect)
    testTemplate(expect, 'wordpress', 'wordpress_Version', 'VersionReader')
  end)

  test('Unit test for Wordpress: PluginsReader', function(expect)
    testTemplate(expect, 'wordpress', 'wordpress_Plugins', 'PluginsReader')
  end)

  ------------------------------------------------ Tests for php -------------------------------------------------------

  test('Unit test for PHP: VersionAndErrorReader', function(expect)
    testTemplate(expect, 'php', 'php_VersionAndError', 'VersionAndErrorReader')
  end)

  test('Unit test for PHP: ModulesReader', function(expect)
    testTemplate(expect, 'php', 'php_Modules', 'ModulesReader')
  end)

  test('Unit test for PHP: ApacheErrorReader', function(expect)
    testTemplate(expect, 'php', 'php_ApacheError', 'ApacheErrorReader')
  end)

end)
