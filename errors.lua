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
local Error = require('core').Error

local UserResponseError = Error:extend()

function UserResponseError:initialize(msg, retnum)
  Error.initialize(self, msg)
  self._retnum = retnum
end

function UserResponseError:get_retnum()
  return self._retnum
end

return {
	Error = Error,
	UserResponseError = UserResponseError,
	AuthTimeoutError = Error:extend(),
	ResponseTimeoutError = Error:extend(),
	InvalidSignatureError = Error:extend()
}
