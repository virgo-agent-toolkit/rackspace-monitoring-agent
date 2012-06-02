--[[
Copyright 2012 Rackspace

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

local Object = require('core').Object
local math = require('math')
local os = require('os')
local string = require('string')

--[[
see http://www.ietf.org/rfc/rfc4122.txt 
Note that this is not a true version 4 (random) UUID.  Since os.time() precision is only 1 second, it would be hard
to guarantee spacial uniqueness when two hosts generate a uuid after being seeded during the same second.  This
is solved by using the node field from a version 1 UUID.  It represents the mac address.
]]

-- seed the random generator.  note that os.time() only offers resolution to one second.
math.randomseed(os.time())

local Uuid = Object:extend()

-- performs the bitwise operation specified by truth matrix on two numbers.
function BITWISE(x, y, matrix)
  local z = 0
  local pow = 1
  while x > 0 or y > 0 do
    z = z + (matrix[x%2+1][y%2+1] * pow)
    pow = pow * 2
    x = math.floor(x/2)
    y = math.floor(y/2)
  end
  return z
end
MATRIX_AND = {{0,0},{0,1} }
MATRIX_OR = {{0,1},{1,1}}

function INT2HEX(x)
  local s,base,pow = '',16,0
  local d
  while x > 0 do
    d = x % base + 1
    x = math.floor(x/base)
    s = string.sub(HEXES, d, d)..s
  end
  if #s == 1 then s = "0" .. s end
  return s
end
function HEX2INT(s)
  
end
HEXES = '0123456789abcdef'

-- hwaddr is a string: hexes delimited by colons. e.g.: 00:0c:29:69:41:c6
function Uuid:initialize(hwaddr)
  -- bytes are treated as 8bit unsigned bytes.
  self._bytes = {
    math.random(0, 255),
    math.random(0, 255),
    math.random(0, 255),
    math.random(0, 255),
    math.random(0, 255),
    math.random(0, 255),
    math.random(0, 255),
    math.random(0, 255),
    math.random(0, 255),
    math.random(0, 255),
    -- no split() in lua. :(
    tonumber(hwaddr:sub(1, 2), 16),
    tonumber(hwaddr:sub(4, 5), 16),
    tonumber(hwaddr:sub(7, 8), 16),
    tonumber(hwaddr:sub(10, 11), 16),
    tonumber(hwaddr:sub(13, 14), 16),
    tonumber(hwaddr:sub(16, 17), 16)
  }
  -- set the version
  self._bytes[7] = BITWISE(self._bytes[7], 0x0f, MATRIX_AND)
  self._bytes[7] = BITWISE(self._bytes[7], 0x40, MATRIX_OR)
  -- set the variant
  self._bytes[9] = BITWISE(self._bytes[7], 0x3f, MATRIX_AND)
  self._bytes[9] = BITWISE(self._bytes[7], 0x80, MATRIX_OR)
  self._string = nil
end

-- lazy string creation.
function Uuid:toString()
  if self._string == nil then
    self._string = INT2HEX(self._bytes[1])..INT2HEX(self._bytes[2])..INT2HEX(self._bytes[3])..INT2HEX(self._bytes[4]).."-"..
         INT2HEX(self._bytes[5])..INT2HEX(self._bytes[6]).."-"..
         INT2HEX(self._bytes[7])..INT2HEX(self._bytes[8]).."-"..
         INT2HEX(self._bytes[9])..INT2HEX(self._bytes[10]).."-"..
         INT2HEX(self._bytes[11])..INT2HEX(self._bytes[12])..INT2HEX(self._bytes[13])..INT2HEX(self._bytes[14])..INT2HEX(self._bytes[15])..INT2HEX(self._bytes[16])
  end
  return self._string
end

return Uuid
