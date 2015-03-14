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

local ffi = require('ffi')

ffi.cdef [[
  int gethostname(char *name, unsigned int namelen);
]]

--[[
  Return the hostname
  @param maxlen{integer,optional} defaults to 255
--]]
return function(maxlen)
  maxlen = maxlen or 255
  local buf = ffi.new("uint8_t[?]", maxlen)
  local res = ffi.C.gethostname(buf, maxlen)
  assert(res == 0)
  return ffi.string(buf, maxlen)
end
