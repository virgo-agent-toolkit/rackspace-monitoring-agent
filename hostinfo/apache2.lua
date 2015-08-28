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
local misc = require('./misc')
local getInfoByVendor = misc.getInfoByVendor
local run = misc.run
local read = misc.read
local Transform = require('stream').Transform
local vumisc = require('virgo/util/misc')
local merge = vumisc.merge
local tableToString = vumisc.tableToString
local async = require('async')
local path = require('path')
--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()

function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
  self._pushed = false
end

local ApacheOutputReader = Reader:extend()
function ApacheOutputReader:_transform(line, cb)
  if line:find('-D HTTPD_ROOT=') then
    self:push({config_path = line:sub(17, line:len()-1)})
  elseif line:find('Server version:') then
    self:push({version = line:sub(17)})
  elseif line:find('Server MPM:') then
    self:push({mpm = line:sub(17)})
  elseif line:find('-D SERVER_CONFIG_FILE=') then
    self:push({config_file = line:sub(25, line:len()-1)})
  elseif line:find('WARNING: Require MaxClients > 0, setting to') then
    self:push({max_clients = line:sub(45):match('%d+')})
  elseif line:find('Syntax OK') then
    self:push({syntax_ok = true})
  elseif line:find('Syntax error') then
    local errs = line:match('%: (.+)')
    self:push({
      syntax_ok = false,
      syntax_errors = errs
    })
  end
  cb()
end

local VhostOutputReader = Reader:extend()
function VhostOutputReader:_transform(line, cb)
  local dataTable = {}
  if line:find('is a NameVirtualHost') then
    self:push({current_vhost = line:match('%S+')})
  elseif line:find('^(%s*)User:') then
    self:push({user = line:match('%"(.*)%"')})
  else
    line:gsub("%S+", function(c) table.insert(dataTable, c) end)
    -- does the line start with default?
    if line:find('^(%s*)default(%s)') then
      self:push({
        vhost = dataTable[3],
        conf = dataTable[4]:match('%((.*)%)') -- strip brackets
      })
      -- does the line start with port?
    elseif line:find('^(%s*)port(%s)') then
      line:gsub("%S+", function(c) table.insert(dataTable, c) end)
      self:push({
        vhost = dataTable[4],
        port = dataTable[2],
        conf = dataTable[5]:match('%((.*)%)') -- strip brackets
      })
    end
  end
  cb()
end

local VhostConfigReader = Reader:extend()
function VhostConfigReader:_transform(line, cb)
  -- '%s+%S+%s+(%S+)' will get the second word in line
  if line:find('^(%s*)DocumentRoot(%s)') then
    self:push({docroot = line:match('%s+%S+%s+(%S+)')})
  elseif line:find('^(%s*)ErrorLog(%s)') then
    self:push({error_log = line:match('%s+%S+%s+(%S+)')})
  elseif line:find('^(%s*)CustomLog(%s)') then
    self:push({access_log = line:match('%s+%S+%s+(%S+)')})
  end
  cb()
end

local PerforkReader = Reader:extend()
function PerforkReader:_transform(line, cb)
  if line:find('<IfModule') and line:find('prefork') then
    -- We do this to check if we're inside the right block for the next block
    self._pushed = true
  end
  if self._pushed and line:find('^(%s*)MaxClients') then
    self:push({max_clients = line:match('%s+%S+%s+(%S+)')})
  end
  cb()
end

--------------------------------------------------------------------------------------------------------------------
--[[ Packages ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  local errTable, outTable = {}, {}

  local deb = {apacheCmd = '/usr/sbin/apache2ctl', apacheArgs = {'-V'},
    vhostCmd = '/usr/sbin/apache2ctl', vhostArgs = {'-S'}}
  local rhel =  {apacheCmd = '/usr/sbin/httpd', apacheArgs = {'-V'},
    vhostCmd = '/usr/sbin/httpd', vhostArgs = {'-S'}}

  local options = {
    ubuntu = deb,
    debian = deb,
    rhel = rhel,
    centos = rhel,
    default = nil
  }

  local spawnConfig = getInfoByVendor(options)
  if not spawnConfig.apacheCmd then
    self._error = string.format("Couldn't decipher linux distro for check %s",  self:getType())
    return callback()
  end

  local function finalCb()
    self:_pushParams(errTable, outTable)
    return callback()
  end

  local function streamToBuffer(stream, cb)
    local outTable, errTable = {}, {}
    stream:on('data', function(data)
      if type(data) == 'table' then
        merge(outTable, data)
      else
        table.insert(outTable, data)
      end
    end)
    stream:on('error', function(err)
      if type(err) == 'table' then
        merge(errTable, err)
      else
        table.insert(errTable, err)
      end
    end)
    stream:once('end', function() cb(outTable, errTable) end)
  end

  local function getApacheOutput(cmd, args, cb)
    local apacheChild = run(cmd, args, {})
    local reader = ApacheOutputReader:new()
    -- We want to capture both stderr and stdout and pass it through the same reader
    apacheChild:on('data', function(data) reader:write(data) end)
    apacheChild:on('error', function(err) reader:write(err) end)
    apacheChild:once('end', function() reader:emit('end') end)
    streamToBuffer(reader, cb)
  end
  local function getApacheClients(cmd, user, cb)
    local cmd = string.format('ps -u %s -o cmd | grep -c %s', user, cmd)
    local child = run('sh', {'-c', cmd}, {})
    streamToBuffer(child, cb)
  end

  local function getVhostsConfig(file, line_number, cb)
    local readStream = read(file)
    -- Catch no file found errors
    readStream:on('error', function(err)
      table.insert(errTable, err)
      return cb()
    end)
    local reader = VhostConfigReader:new()
    local iterCount = 1
    readStream:on('data', function(data)
      iterCount = iterCount + 1
      if iterCount >= tonumber(line_number) then
        reader:write(data)
      end
    end)
    readStream:once('end', function()
      reader:emit('end')
    end)
    streamToBuffer(reader, cb)
  end
  local function getVhostsOutput(cmd, args, cb)
    local outTable, errTable, current_vhost = {}, {}, ''
    local child = run(cmd, args, {})
    local reader = VhostOutputReader:new()
    local waitCount = 1 -- we wish to wait for the end of the reader stream
    local function await()
      waitCount = waitCount - 1
      if waitCount == 0 then cb(outTable, errTable) end
    end
    child:pipe(reader)
    reader:on('data', function(data)
      -- Handleline: *:80 is a NameVirtualHost
      if data.current_vhost then
        current_vhost = data.current_vhost
        outTable.vhosts = {}
        outTable.vhosts[current_vhost] = {}
      end
      if data.user then merge(outTable, data) end
      if data.conf then
        local file, lineNum = data.conf:match("(.+)%:(.+)")
        if not data.port then
          -- Handleline: default server 2001:4800:7812:514:be76:4eff:fe05:678d (/etc/apache2/sites-enabled/000-default.conf:1)
          waitCount = waitCount + 1
          getVhostsConfig(file, lineNum, function(out, err)
            if err then table.insert(errTable, err) end
            outTable.vhosts[current_vhost]['default'] = {
              vhost = data.vhost,
              conf = data.conf,
              docroot = out['docroot'] or '',
              accesslogs = out['access_logs'] or '',
              errorlog = out['error_log'] or ''
            }
            await()
          end)
        else
          -- Handleline: port 80 namevhost example.com (/etc/apache2/sites-enabled/example.com.conf:1)
          waitCount = waitCount + 1
          getVhostsConfig(file, lineNum, function(out, err)
            if err then table.insert(errTable, err) end
            outTable.vhosts[current_vhost][data.vhost] = {
              vhost = data.vhost,
              conf = data.conf,
              port = data.port,
              docroot = out['docroot'] or '',
              accesslogs = out['access_log'] or '',
              errorlog = out['error_log'] or ''
            }
            await()
          end)
        end
      end
    end)
    reader:once('end', function() await() end)
  end
  local function getRamPerPreforkChild(user, cb)
    local cmd =  string.format("ps -u %s -o pid= | xargs pmap -d | awk '/private/ \
               {c+=1; sum+=$4} END {printf \"%.2f\", sum/c/1024}'", user)
    local stream = run('sh', {'-c', cmd}, {})
    streamToBuffer(stream, cb)
  end

  outTable.bin = spawnConfig.apacheCmd

  async.parallel({
    function(cb)
      getApacheOutput(spawnConfig.apacheCmd, spawnConfig.apacheArgs, function(out, err)
        merge(outTable, out)
        merge(errTable, err)
        if not outTable.syntax_ok then outTable.syntax_ok = true end
        cb()
      end)
    end,
    function(cb)
      getVhostsOutput(spawnConfig.vhostCmd, spawnConfig.vhostArgs, function(out, err)
        merge(outTable, out)
        merge(errTable, err)
        getApacheClients(spawnConfig.apacheConfig, outTable.user, function(out, err)
          outTable.cients = out and table.concat(out) or ''
          merge(errTable, err)
          cb()
        end)
      end)
    end
  }, function()
    if outTable.config_file then
      outTable.config_file = path.join(outTable.config_path, outTable.config_file)
    end
    if outTable.mpm == 'prefork' and #outTable.user ~= 0 then
      getRamPerPreforkChild(outTable.user, function(out, err)
        outTable.estimatedRAMperpreforkchild = type(out) == 'table' and tableToString(out) or out
        merge(errTable, err)
        local readStream = read(outTable.config_file)
        readStream:on('error', function(err)
          table.insert(errTable, err)
          return finalCb()
        end)
        local reader = PerforkReader:new()
        readStream:pipe(reader)
        streamToBuffer(reader, function(out, err)
          merge(errTable, err)
          if out.max_clients > 0 then outTable.max_clients = out.max_clients end
          return finalCb()
        end)
      end)
    else
      return finalCb()
    end
  end)
end

function Info:getPlatforms()
  return {'linux', 'darwin'}
end

function Info:getType()
  return 'APACHE2'
end

exports.Info = Info
exports.ApacheOutputReader = ApacheOutputReader
exports.VhostConfigReader = VhostConfigReader
exports.VhostOutputReader = VhostOutputReader
exports.PerforkReader = PerforkReader -- untested