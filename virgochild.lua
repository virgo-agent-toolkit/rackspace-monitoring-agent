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
local childprocess = require('childprocess')
local net = require('net')

local function spawn(command, args, options)
  if not options then
    options = {}
  end
  
  if not options.stdio then
    options.stdio = {
      nil,
      net.Socket:new({ handle = uv.new_pipe(false) }),
      net.Socket:new({ handle = uv.new_pipe(false) })
    }
  end

  return childprocess.spawn(command, arg, options)
end


exports.spawn = spawn
