local Error = require('core').Error

local SetupError = Error:extend()

local exports = {}
exports.SetupError = SetupError
return exports
