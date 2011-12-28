local Error = {}

local error_prototype = {}
setmetatable(error_prototype, error_meta)
Error.prototype = error_prototype

-- Used by things inherited from Error
Error.meta = {__index=Error.prototype}

Error.new = function(message)
  local err = {
    message = message
  }
  setmetatable(err, error_meta)
  return err
end

return Error
