local coroutine = require('coroutine')
local table = require('table')

local exports = {}

local SENTINEL = {}
exports.SENTINEL = SENTINEL
exports.yield = coroutine.yield

local _unpack = function(...)
  -- this function is necessary because of the way lua
  --handles nil within tables and in unpack
  local args = {...}
  local coro_status = false
  local next_call = nil
  local extras = {}
  for k,v in pairs(args) do
    if k == 1 then
      coro_status = v
    elseif k == 2 then
      next_call = v
    else
      extras[k-2] = v
    end
  end
  return coro_status, next_call, extras
end

exports.__inline_callbacks = function(coro, cb, ...)
  local v = ...
  local previous = nil
  local no_errs = true
  local extra_args = {}
  while true do
    previous = v

    if coroutine.status(coro) == 'dead' then
      -- todo- pcall this and shove the result into the second argument or return an error or something
      if type(previous) ~= 'table' then
        return cb(previous)
      else
        return cb(unpack(previous))
      end
    end
     -- yielded a function...
    if type(v) == 'function' then
       -- add a callback that will invoke coro
      local f = function(...)
        -- we resume ourselves later
        return exports.__inline_callbacks(coro, cb, ...)
      end
      -- replace the sentinel if it exists, with the function
      if extra_args[#extra_args] == SENTINEL then
        extra_args[#extra_args] = f
      else
        table.insert(extra_args, f)
      end
      return v(unpack(extra_args))
    end

    no_errs, v, extra_args = _unpack(coroutine.resume(coro, v))

    -- donegoofed?
    if no_errs ~= true then
      return cb(v)
    end

  end
end

exports.inline_callbacks = function(f)
  local coro = coroutine.create(f)
  return function(cb, ...)
    return exports.__inline_callbacks(coro, cb, ...)
  end
end

return exports