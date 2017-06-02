--[[
Copyright 2016 Rackspace

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

local read = require('virgo/util/misc').read
local async = require('async')
local fs = require('fs')
local path = require('path')
local trim = require('virgo/util/misc').trim
local Transform = require('stream').Transform

--------------------------------------------------------------------------------------------------------------------
local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(line, cb)
  local module_interface, control_flags, module_name,
  module_arguments, _, soEnd, iter, keywords

  keywords = {
    password = true,
    auth = true,
    account = true,
    session = true
  }
  -- Sometimes the lines are seperated with \t(tabs) instead of spaces
  if line:find('%\t') then
    iter = line:gmatch('%\t')
  else
    iter = line:gmatch('%S+')
  end
  module_interface = iter()
  if keywords[module_interface] then
    _, soEnd = line:find('%.so')
    -- sometimes the pam files have many control flags
    if line:find('%]') then
      control_flags = line:sub(line:find('%[')+1, line:find('%]')-1)
      module_name = line:sub(line:find('%]')+2, soEnd)
    else
      control_flags = iter()
      module_name = iter()
    end
    -- They also like to have variable numbers of module args
    if soEnd and line:len() ~= soEnd then
      module_arguments = line:sub(soEnd+2)
    end
    self:push({
      module_interface = trim(module_interface),
      control_flags = trim(control_flags),
      module_name = trim(module_name),
      module_arguments = trim(module_arguments) or ''
    })
  end
  return cb()
end
--------------------------------------------------------------------------------------------------------------------

--[[ Pluggable auth modules ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end
function Info:_run(callback)
  local PAM_PATH = '/etc/pam.d'
  local CONCURRENCY = 5
  local errTable, outTable = {}, {}

  local function finalCb()
    self:_pushParams(errTable, outTable)
    return callback()
  end

  local function onreadDir(err, files)
    if err then table.insert(errTable, err) end
    if not files or #files == 0 then return finalCb() end
    local function iter(file, cb)
      local readStream = read(path.join(PAM_PATH, file))
      local reader = Reader:new()
      -- Catch no file found errors
      readStream:on('error', function(err)
        table.insert(errTable, err)
        return cb()
      end)
      readStream:pipe(reader)
      reader:on('data', function(data)
        -- set filename
        data.file_name = file
        table.insert(outTable, data)
      end)
      reader:on('error', function(err) table.insert(errTable, err) end)
      reader:once('end', cb)
    end
    async.forEachLimit(files, CONCURRENCY, iter, finalCb)
  end

  fs.readdir(PAM_PATH, onreadDir)
end

function Info:getType()
  return 'PAM'
end

function Info:getPlatforms()
  return {'linux'}
end

exports.Info = Info
exports.Reader = Reader
