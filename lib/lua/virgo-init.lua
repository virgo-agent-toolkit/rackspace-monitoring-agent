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
--_oldprint = print
_G.print = nil

-- Load libraries used in this file
-- Load libraries used in this file
local debugm = require('debug')
local uv = require('uv')
local env = require('env')
local table = require('table')
local utils = require('utils')
local fs = require('fs')
local Tty = require('tty').Tty
local Emitter = require('core').Emitter
local constants = require('constants')
local path = require('path')
local LVFS = VFS
_G.VFS = nil

-- Copy date and binding over from lua os module into luvit os module
local OLD_OS = require('os')
local OS_BINDING = require('os_binding')
package.loaded.os = OS_BINDING
package.preload.os_binding = nil
package.loaded.os_binding = nil
OS_BINDING.date = OLD_OS.date
OS_BINDING.time = OLD_OS.time

process = Emitter:new()

process.version = VERSION
process.versions = {
  luvit = VERSION,
  uv = uv.VERSION_MAJOR .. "." .. uv.VERSION_MINOR .. "-" .. UV_VERSION,
  luajit = LUAJIT_VERSION,
  yajl = YAJL_VERSION,
  http_parser = HTTP_VERSION,
}
_G.VERSION = nil
_G.YAJL_VERSION = nil
_G.LUAJIT_VERSION = nil
_G.UV_VERSION = nil
_G.HTTP_VERSION = nil

local vfs = LVFS.open()

function process.exit(exit_code)
  process:emit('exit', exit_code)
  exitProcess(exit_code or 0)
end

function process:addHandlerType(name)
  local code = constants[name]
  if code then
    uv.activateSignalHandler(code)
    uv.unref()
  end
end

function process:missingHandlerType(name, ...)
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
hide("exitProcess")

-- Ignore sigpipe and exit cleanly on SIGINT and SIGTERM
-- These shouldn't hold open the event loop
if luvit_os ~= "win" then
  uv.activateSignalHandler(constants.SIGPIPE)
  uv.unref()
  uv.activateSignalHandler(constants.SIGINT)
  uv.unref()
  uv.activateSignalHandler(constants.SIGTERM)
  uv.unref()
end

-- Load the tty as a pair of pipes
-- But don't hold the event loop open for them
process.stdin = Tty:new(0)
process.stdout = Tty:new(1)
local stdout = process.stdout
uv.unref()
uv.unref()


-- Replace print
function print(...)
  local n = select('#', ...)
  local arguments = { ... }

  for i = 1, n do
    arguments[i] = tostring(arguments[i])
  end

  stdout:write(table.concat(arguments, "\t") .. "\n")
end

-- A nice global data dumper
function p(...)
  local n = select('#', ...)
  local arguments = { ... }

  for i = 1, n do
    arguments[i] = utils.dump(arguments[i])
  end

  stdout:write(table.concat(arguments, "\t") .. "\n")
end

hide("printStderr")
-- Like p, but prints to stderr using blocking I/O for better debugging
function debug(...)
  local n = select('#', ...)
  local arguments = { ... }

  for i = 1, n do
    arguments[i] = utils.dump(arguments[i])
  end

  printStderr(table.concat(arguments, "\t") .. "\n")
end


-- Add global access to the environment variables using a dynamic table
process.env = setmetatable({}, {
  __pairs = function (table)
    local keys = env.keys()
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
    return env.get(name)
  end,
  __newindex = function (table, name, value)
    if value then
      env.set(name, value, 1)
    else
      env.unset(name)
    end
  end
})

-- This is called by all the event sources from C
-- The user can override it to hook into event sources
function eventSource(name, fn, ...)
  local args = {...}
  return assert(xpcall(function ()
    return fn(unpack(args))
  end, debugm.traceback))
end

error_meta = {__tostring=function(table) return table.message end}

local global_meta = {__index=_G}


local function partialRealpath(filepath)
  -- Do some minimal realpathing
  local link
  link = fs.lstatSync(filepath).is_symbolic_link and fs.readlinkSync(filepath)
  while link do
    filepath = path.resolve(path.dirname(filepath), link)
    link = fs.lstatSync(filepath).is_symbolic_link and fs.readlinkSync(filepath)
  end
  return path.normalize(filepath)
end


local function myloadfile(filepath)
  if not vfs:exists(filepath) then return end
  -- Not done by luvit, we don't have synlinks in the zip file.
  -- filepath = partialRealpath(filepath)

  if package.loaded[filepath] then
    return function ()
      return package.loaded[filepath]
    end
  end

  local code = vfs:read(filepath)

  -- TODO: find out why inlining assert here breaks the require test
  local fn, err = loadstring(code, '@' .. filepath)
  assert(fn, err)
  local dirname = path.dirname(filepath)
  local realRequire = require
  setfenv(fn, setmetatable({
    __filename = filepath,
    __dirname = dirname,
    require = function (filepath)
      return realRequire(filepath, dirname)
    end,
  }, global_meta))
  local module = fn()
  package.loaded[filepath] = module
  return function() return module end
end

local function myloadlib(filepath)
  if not vfs:exists(filepath) then return end

  filepath = partialRealpath(filepath)

  if package.loaded[filepath] then
    return function ()
      return package.loaded[filepath]
    end
  end

  local name = path.basename(filepath)
  if name == "init.luvit" then
    name = path.basename(path.dirname(filepath))
  end
  local base_name = name:sub(1, #name - 6)
  package.loaded[filepath] = base_name -- Hook to allow C modules to find their path
  local fn, error_message = package.loadlib(filepath, "luaopen_" .. base_name)
  if fn then
    local module = fn()
    package.loaded[filepath] = module
    return function() return module end
  end
  error(error_message)
end

-- tries to load a module at a specified absolute path
local function loadModule(filepath, verbose)

  -- First, look for exact file match if the extension is given
  local extension = path.extname(filepath)
  if extension == ".lua" then
    return myloadfile(filepath)
  end
  if extension == ".luvit" then
    return myloadlib(filepath)
  end

  -- Then, look for module/package.lua config file
  if vfs:exists(filepath .. "/package.lua") then
    local metadata = loadModule(filepath .. "/package.lua")()
    if metadata.main then
      return loadModule(path.join(filepath, metadata.main))
    end
  end

  -- Try to load as either lua script or binary extension
  local fn = myloadfile(filepath .. ".lua") or myloadfile(filepath .. "/init.lua")
          or myloadlib(filepath .. ".luvit") or myloadlib(filepath .. "/init.luvit")
  if fn then return fn end

  return "\n\tCannot find module " .. filepath
end

-- Remove the cwd based loaders, we don't want them
local builtinLoader = package.loaders[1]
package.loaders = nil
package.path = nil
package.cpath = nil
package.searchpath = nil
package.seeall = nil
package.config = nil
_G.module = nil

function require(filepath, dirname)
  if not dirname then dirname = base_path end

  -- Absolute and relative required modules
  local first = filepath:sub(1, 1)
  local absolute_path
  if first == "/" then
    absolute_path = path.normalize(filepath)
  elseif first == "." then
    absolute_path = path.join(dirname, filepath)
  end
  if absolute_path then
    local loader = loadModule(absolute_path)
    if type(loader) == "function" then
      return loader()
    else
      error("Failed to find module '" .. filepath .."'")
    end
  end

  local errors = {}

  -- Builtin modules
  local module = package.loaded[filepath]
  if module then return module end
  if filepath:find("^[a-z_]+$") then
    local loader = builtinLoader(filepath)
    if type(loader) == "function" then
      module = loader()
      package.loaded[filepath] = module
      return module
    else
      errors[#errors + 1] = loader
    end
  end

  -- Bundled path modules
  local dir = dirname .. "/"
  repeat
    dir = dir:sub(1, dir:find("/[^/]*$") - 1)
    local full_path = dir .. "/modules/" .. filepath
    local loader = loadModule(dir .. "/modules/" .. filepath)
    if type(loader) == "function" then
      return loader()
    else
      errors[#errors + 1] = loader
    end
  until #dir == 0

  error("Failed to find module '" .. filepath .."'" .. table.concat(errors, ""))

end

local virgo_init = {}

function virgo_init.run(name)
  local mod = require(name)

  assert(xpcall(mod.run, debugm.traceback))

  -- Start the event loop
  uv.run()
  -- trigger exit handlers and exit cleanly
  process.exit(0)
end

return virgo_init
