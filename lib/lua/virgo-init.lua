VERSION = "TODO:Put_Version_here"
-- clear some globals
-- This will break lua code written for other lua runtimes
_G.io = nil
_G.os = nil
_G.math = nil
_G.string = nil
_G.coroutine = nil
_G.jit = nil
_G.bit = nil
_G.debug = nil
_G.table = nil
_G.loadfile = nil
_G.dofile = nil
_G.print = nil

-- Load libraries used in this file
local Debug = require('debug')

local UV = require('uv')
local Env = require('env')

local Table = require('table')
local Utils = require('utils')
local FS = require('fs')
local TTY = require('tty')
local Emitter = require('emitter')
local Constants = require('constants')
local Path = require('path')

local LVFS = VFS
_G.VFS = nil

local vfs = LVFS.open()

process = Emitter.new()

function process.exit(exit_code, clean)
  process:emit('exit', exit_code)
  if (clean ~= 1) then
    exit_process(exit_code or 0)
  end
end

function process:add_handler_type(name)
  local code = Constants[name]
  if code then
    UV.activate_signal_handler(code)
    UV.unref()
  end
end

function process:missing_handler_type(name, ...)
  if name == "error" then
    error(...)
  elseif name == "SIGINT" or name == "SIGTERM" then
    process.exit()
  end
end

process.cwd = getcwd
_G.getcwd = nil
process.argv = argv
_G.argv = nil

local base_path = process.cwd()

-- Hide some stuff behind a metatable
local hidden = {}
setmetatable(_G, {__index=hidden})
local function hide(name)
  hidden[name] = _G[name]
  _G[name] = nil
end
hide("_G")
hide("exit_process")

-- Remove the cwd based loaders, we don't want them
local builtin_loader = package.loaders[1]
package.loaders = nil
package.path = nil
package.cpath = nil
package.searchpath = nil
package.seeall = nil
package.config = nil
_G.module = nil


-- Ignore sigpipe and exit cleanly on SIGINT and SIGTERM
-- These shouldn't hold open the event loop
if virgo_os ~= "win" then
  UV.activate_signal_handler(Constants.SIGPIPE)
  UV.unref()
  UV.activate_signal_handler(Constants.SIGINT)
  UV.unref()
  UV.activate_signal_handler(Constants.SIGTERM)
  UV.unref()
end

-- Load the tty as a pair of pipes
-- But don't hold the event loop open for them
process.stdin = TTY.new(0)
UV.unref()
process.stdout = TTY.new(1)
UV.unref()
local stdout = process.stdout

-- Replace print
function print(...)
  local n = select('#', ...)
  local arguments = { ... }

  for i = 1, n do
    arguments[i] = tostring(arguments[i])
  end

  stdout:write(Table.concat(arguments, "\t") .. "\n")
end

-- A nice global data dumper
function p(...)
  local n = select('#', ...)
  local arguments = { ... }

  for i = 1, n do
    arguments[i] = Utils.dump(arguments[i])
  end

  stdout:write(Table.concat(arguments, "\t") .. "\n")
end

hide("print_stderr")
-- Like p, but prints to stderr using blocking I/O for better debugging
function debug(...)
  local n = select('#', ...)
  local arguments = { ... }

  for i = 1, n do
    arguments[i] = Utils.dump(arguments[i])
  end

  print_stderr(Table.concat(arguments, "\t") .. "\n")
end


-- Add global access to the environment variables using a dynamic table
process.env = setmetatable({}, {
  __pairs = function (table)
    local keys = Env.keys()
    local index = 0
    return function (...)
      index = index + 1
      local name = keys[index]
      if name then
        return name, table[name]
      end
    end
  end,
  __index = function (table, name)
    return Env.get(name)
  end,
  __newindex = function (table, name, value)
    if value then
      Env.set(name, value, 1)
    else
      Env.unset(name)
    end
  end
})

_G.VFS = nil -- done with VFS module
local global_meta = {__index=_G}

-- This is called by all the event sources from C
-- The user can override it to hook into event sources
function event_source(name, fn, ...)
  local args = {...}
  return assert(xpcall(function ()
    return fn(unpack(args))
  end, Debug.traceback))
end

local function myloadfile(path)
  if not vfs:exists(path) then return end

  if package.loaded[path] then
    return function ()
      return package.loaded[path]
    end
  end

  local code = vfs:read(path)

  local fn = assert(loadstring(code, '@' .. path))
  local dirname = Path.dirname(path)
  setfenv(fn, setmetatable({
    __filename = path,
    __dirname = dirname,
    require = function (path)
      return virgo_require(path, dirname)
    end,
  }, global_meta))
  local module = fn()
  package.loaded[path] = module
  return function() return module end
end

-- tries to load a module at a specified absolute path
local function load_module(path, verbose)

  -- First, look for exact file match if the extension is given
  local extension = Path.extname(path)
  if extension == ".lua" then
    return myloadfile(path)
  end

  -- Then, look for module/package.lua config file
  if vfs:exists(path .. "/package.lua") then
    local metadata = load_module(path .. "/package.lua")()
    if metadata.main then
      return load_module(Path.join(path, metadata.main))
    end
  end

  -- Try to load as either lua script or binary extension
  local fn = myloadfile(path .. ".lua") or myloadfile(path .. "/init.lua")
  if fn then return fn end

  return "\n\tCannot find module " .. path
end


function virgo_require(path, dirname)
  if not dirname then dirname = '' end

  -- Absolute and relative required modules
  local first = path:sub(1, 1)
  local absolute_path
  if first == "/" then
    absolute_path = Path.normalize(path)
  elseif first == "." then
    absolute_path = Path.join(dirname, path)
  end
  if absolute_path then
    local loader = load_module(absolute_path)
    if type(loader) == "function" then
      return loader()
    else
      error("Failed to find module '" .. path .."'")
    end
  end

  local errors = {}

  -- Builtin modules
  local module = package.loaded[path]
  if module then return module end
  if path:find("^[a-z_]+$") then
    local loader = builtin_loader(path)
    if type(loader) == "function" then
      module = loader()
      package.loaded[path] = module
      return module
    end
  end

  -- Bundled path modules
  local dir = dirname .. "/"
  repeat
    dir = dir:sub(1, dir:find("/[^/]*$") - 1)
    local full_path = dir .. "/modules/" .. path
    local loader = load_module(full_path)
    if type(loader) == "function" then
      return loader()
    else
      errors[#errors + 1] = loader
    end
  until #dir == 0

  error("Failed to find module '" .. path .."'" .. Table.concat(errors, ""))

end

error_meta = {__tostring=function(table) return table.message end}

require = virgo_require

local virgo_init = {}

function virgo_init.run(name)
  local mod = require(name)

  mod.run()

  -- Start the event loop
  UV.run()
  -- trigger exit handlers and exit cleanly
  process.exit(0, 1)
end

return virgo_init
