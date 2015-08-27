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
    test('Auto test:' .. checkName, function(expect)
      local hostinfo = require('../hostinfo/'..checkName)
      local errTable, outTable = {}, {}
      local reader = hostinfo.Reader:new()
      local inFixture = LineEmitter:new()
      local outFixture = hostinfoFixtureDir[checkName..'_out.txt']
      local cb = expect(function()
        local outFixtureTable = json.parse(outFixture)
        assert(is_equal(outFixtureTable, outTable), 'not ok: outFixture and outTable dont match')
        assert(#errTable==0, 'Not ok: errtable is not 0 length')
      end)
      inFixture:pipe(reader)
      reader:on('error', function(err) table.insert(errTable, err) end)
      reader:on('data', function(data) table.insert(outTable, data) end)
      reader:once('end', cb)
      local chunk = hostinfoFixtureDir[checkName..'_in.txt']
      inFixture:write(chunk)
      inFixture:write()
    end)
  end

  ---------------------------------------------- Tests for Autoupdates ------------------------------------------------

  test('test for Autoupdates: apt reader enabled', function(expect)
    local autoupdates = require('../hostinfo/autoupdates')
    local errTable, outTable = {}, {}
    local reader = autoupdates.AptReader:new()
    local inFixture = LineEmitter:new()
    local outFixture = hostinfoFixtureDir['autoupdates_apt_out.txt']
    local cb = expect(function()
      local outFixtureTable = json.parse(outFixture)
      assert(is_equal(outFixtureTable, outTable), 'not ok: outFixture and outTable dont match')
      assert(#errTable==0, 'Not ok: errtable is not 0 length')
    end)
    inFixture:pipe(reader)
    reader:on('error', function(err) table.insert(errTable, err) end)
    reader:on('data', function(data) table.insert(outTable, data) end)
    reader:once('end', cb)
    local chunk = hostinfoFixtureDir['autoupdates_apt_in.txt']
    inFixture:write(chunk)
    inFixture:write()
  end)

  test('test for Autoupdates: yum reader enabled', function(expect)
    local autoupdates = require('../hostinfo/autoupdates')
    local errTable, outTable = {}, {}
    local reader = autoupdates.YumReader:new()
    local inFixture = LineEmitter:new()
    local outFixture = hostinfoFixtureDir['autoupdates_yum_out.txt']
    local cb = expect(function()
      local outFixtureTable = json.parse(outFixture)
      assert(is_equal(outFixtureTable, outTable), 'not ok: outFixture and outTable dont match')
      assert(#errTable==0, 'Not ok: errtable is not 0 length')
    end)
    inFixture:pipe(reader)
    reader:on('error', function(err) table.insert(errTable, err) end)
    reader:on('data', function(data) table.insert(outTable, data) end)
    reader:once('end', cb)
    local chunk = hostinfoFixtureDir['autoupdates_yum_in.txt']
    inFixture:write(chunk)
    inFixture:write(nil)
  end)

  ----------------------------------------------- Tests for packages --------------------------------------------------

  test('test for packages: linux reader', function(expect)
    local autoupdates = require('../hostinfo/packages')
    local errTable, outTable = {}, {}
    local reader = autoupdates.LinuxReader:new()
    local inFixture = LineEmitter:new()
    local outFixture = hostinfoFixtureDir['packages_linux_out.txt']
    local cb = expect(function()
      local outFixtureTable = json.parse(outFixture)
      assert(is_equal(outFixtureTable, outTable), 'not ok: outFixture and outTable dont match')
      assert(#errTable==0, 'Not ok: errtable is not 0 length')
    end)
    inFixture:pipe(reader)
    reader:on('error', function(err) table.insert(errTable, err) end)
    reader:on('data', function(data) table.insert(outTable, data) end)
    reader:once('end', cb)
    local chunk = hostinfoFixtureDir['packages_linux_in.txt']
    inFixture:write(chunk)
    inFixture:write(nil)
  end)
  ----------------------------------------------- Tests for apache2 --------------------------------------------------
  local hostinfo = require('../hostinfo/apache2')
  test('test for apache2: apache output reader', function(expect)
    local errTable, outTable = {}, {}
    local reader = hostinfo.ApacheOutputReader:new()
    local inFixture = LineEmitter:new()
    local outFixture = hostinfoFixtureDir['apache2_apacheOut_out.txt']
    local cb = expect(function()
      local outFixtureTable = json.parse(outFixture)
      assert(is_equal(outFixtureTable, outTable), 'not ok: outFixture and outTable dont match')
      assert(#errTable==0, 'Not ok: errtable is not 0 length')
    end)
    inFixture:pipe(reader)
    reader:on('error', function(err) table.insert(errTable, err) end)
    reader:on('data', function(data) table.insert(outTable, data) end)
    reader:once('end', cb)
    local chunk = hostinfoFixtureDir['apache2_apacheOut_in.txt']
    inFixture:write(chunk)
    inFixture:write(nil)
  end)

  test('test for apache2: VhostOutputReader', function(expect)
    local errTable, outTable = {}, {}
    local reader = hostinfo.VhostOutputReader:new()
    local inFixture = LineEmitter:new()
    local outFixture = hostinfoFixtureDir['apache2_VhostOutput_out.txt']
    local cb = expect(function()
      local outFixtureTable = json.parse(outFixture)
      assert(is_equal(outFixtureTable, outTable), 'not ok: outFixture and outTable dont match')
      assert(#errTable==0, 'Not ok: errtable is not 0 length')
    end)
    inFixture:pipe(reader)
    reader:on('error', function(err) table.insert(errTable, err) end)
    reader:on('data', function(data) table.insert(outTable, data) end)
    reader:once('end', cb)
    local chunk = hostinfoFixtureDir['apache2_VhostOutput_in.txt']
    inFixture:write(chunk)
    inFixture:write(nil)
  end)

  test('test for apache2: VhostConfigReader', function(expect)
    local errTable, outTable = {}, {}
    local reader = hostinfo.VhostConfigReader:new()
    local inFixture = LineEmitter:new()
    local outFixture = hostinfoFixtureDir['apache2_VhostConfig_out.txt']
    local cb = expect(function()
      local outFixtureTable = json.parse(outFixture)
      assert(is_equal(outFixtureTable, outTable), 'not ok: outFixture and outTable dont match')
      assert(#errTable==0, 'Not ok: errtable is not 0 length')
    end)
    inFixture:pipe(reader)
    reader:on('error', function(err) table.insert(errTable, err) end)
    reader:on('data', function(data) table.insert(outTable, data) end)
    reader:once('end', cb)
    local chunk = hostinfoFixtureDir['apache2_VhostConfig_in.txt']
    inFixture:write(chunk)
    inFixture:write(nil)
  end)
end)
