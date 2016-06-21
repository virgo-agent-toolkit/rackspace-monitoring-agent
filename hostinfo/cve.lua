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
local HostInfo = require('./base').HostInfo
local Transform = require('stream').Transform
local misc = require('./misc')
--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()

function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(line, cb)
  local cvestart, _ = line:find('CVE-')
  local cvestr = line:sub(cvestart, cvestart+12)
  -- we want unique cves only
  self:push(cvestr)
  cb()
end
--------------------------------------------------------------------------------------------------------------------
--[[ Check CVE fixes ]]--
local Info = HostInfo:extend()

function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local errTable, outTable = {}, {}
  local deb = {cmd = '/bin/sh', args = {'-c',  'zcat /usr/share/doc/*/changelog.Debian.gz | grep CVE-'} }
  local rhel = {cmd = '/bin/sh', args = {'-c', 'rpm -qa --changelog | grep CVE-'} }

  local options = {
    ubuntu = deb,
    debian = deb,
    rhel = rhel,
    centos = rhel,
    fedora = rhel,
    default = nil
  }

  local spawnConfig = misc.getInfoByVendor(options)
  if not spawnConfig.cmd then
    self._error = string.format("Couldn't decipher linux distro for check %s",  self:getType())
    return callback()
  end
  local cmd, args = spawnConfig.cmd, spawnConfig.args

  local function finalCb()
    -- Sort the cves
    local tempTable = {}
    for key, _ in pairs(outTable) do
      table.insert(tempTable, key)
    end
    table.sort(tempTable)
    -- Assign a key to the array of CVEs before we send them back to prevent serialization problems
    -- i.e. ["CVE-2015-24", "CVE-2015-12"] becomes ["1": "C", "2":"V"...] otherwise
    self:_pushParams(errTable, {['patched_CVE'] = tempTable})
    return callback()
  end

  local reader = Reader:new()
  local child = misc.run(cmd, args)
  child:pipe(reader)
  reader:on('data', function(data)
    outTable[data] = 1
  end)
  reader:on('error', function(data)
    table.insert(errTable, data)
  end)
  reader:once('end', finalCb)
end

function Info:getPlatforms()
  return {'linux'}
end

function Info:getType()
  return 'CVE'
end

exports.Info = Info
exports.Reader = Reader
