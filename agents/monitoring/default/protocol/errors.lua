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

local fmt = require('string').format
local Error = require('core').Error

local ProtocolError = Error:extend()
function ProtocolError:initialize(msg)
  self['original'] = msg
  self['code'] = msg['code'] or 'unknown'
  self['type'] = msg['type'] or 'unknown'
  self['msg'] = msg['message'] or 'no message'

  self.message = fmt('%s error: code=%s, message=%s',
    self['type'], self['code'], self['msg'])
  Error.initialize(self, self.message)
end

local VersionError = Error:extend()
function VersionError:initialize(msg, resp)
  Error.initialize(self)
  self.message = fmt(
      'Version mismatch: message_version=%s response_version=%s',
      msg.v or 'unknown',
      resp.v or 'unknown')
end

local InvalidMethodError = Error:extend()
function InvalidMethodError:initialize(method)
  Error.initialize(self)
  self.message = fmt('invalid method method=%s', method)
  self.method = method
end

local exports = {}
exports.ProtocolError = ProtocolError
exports.VersionError = VersionError
exports.InvalidMethodError = InvalidMethodError
return exports
