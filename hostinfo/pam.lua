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
local LineEmitter = require('line-emitter').LineEmitter
local async = require('async')
local fs = require('fs')
local los = require('los')
local path = require('path')
local Transform = require('stream').Transform

local PAM_PATH = '/etc/pam.d'
local CONCURRENCY = 5

local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end

function Reader:_transform(line, callback)
  local keywords = {
    password = true,
    auth = true,
    account = true,
    session = true
  }
  if line:sub(1, 1) == '#' then return callback() end
  local iter = line:gmatch('%S+')
  local module_interface = iter()
  if not keywords[module_interface] then return callback() end
  local _, soEnd = line:find('%.so')
  local control_flags, module_name, module_arguments
  -- sometimes the pam files have many control flags
  if line:find('%]') then
    control_flags = line:sub(line:find('%[')+1, line:find('%]')-1)
    module_name = line:sub(line:find('%]')+2, soEnd)
  else
    control_flags = iter()
    module_name = iter()
  end
  -- They also like to have variable numbers of module args
  if line:len() ~= soEnd and soEnd ~= nil then
    module_arguments = line:sub(soEnd+2, line:len())
  end
  self:push({
    module_interface = module_interface,
    control_flags = control_flags,
    module_name = module_name,
    module_arguments = module_arguments or ''
  })
  callback()
end

local Info = HostInfo:extend()

function Info:run(callback)
  if los.type() == 'win32' then
    self._error = 'unsupported operating system'
    return callback()
  end
  local function onReadDir(err, files)
    if err then
      self._error = err.message
      return callback()
    end
    local function iter(file, callback)
      local stream = fs.createReadStream(path.join(PAM_PATH, file))
      local reader = Reader:new()
      local params = {}
      stream:pipe(LineEmitter:new()):pipe(reader)
      reader:on('data', function(param)
        table.insert(params, param)
      end)
      reader:once('end', function()
        table.insert(self._params, { file = file, params = params })
        callback()
      end)
    end
    async.forEachLimit(files, CONCURRENCY, iter, callback)
  end
  fs.readdir(PAM_PATH, onReadDir)
end

function Info:getType()
  return 'PAM'
end

return Info
