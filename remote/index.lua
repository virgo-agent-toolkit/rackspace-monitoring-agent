local uv = require('uv')

local modules = {
  tcp = require('./tcp')
}

return function (attributes, config, callback)
  local fn = assert(modules[attributes.module], "Missing module")

  local done
  local handles = {}
  local result = { id = attributes.id }

  -- Register a uv_handle to be cleaned up when done.
  local function register(handle)
    if done then
      return handle:close()
    end
    handles[#handles + 1] = handle
  end

  -- Set part of the result data.
  local function set(key, value)
    result[key] = value
  end

  -- Called when done with optional error reason
  local function finish(err)
    if done then return end
    done = true
    for i = 1, #handles do
      if not handles[i]:is_closing() then handles[i]:close() end
    end
    result.error = err
    return callback(err, result)
  end

  local timer = uv.new_timer()
  register(timer)
  timer:start(attributes.timeout, 0, function ()
    return finish("ETIMEOUT: Check did not finish within " .. attributes.timeout .. "ms")
  end)

  coroutine.wrap(function ()
    local success, err = pcall(fn, attributes, config, register, set)
    if not success then
      return finish(err)
    end
    return finish()
  end)()
end
