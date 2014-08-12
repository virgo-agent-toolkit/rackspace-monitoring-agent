local http = require('http')
local https = require('https')
local url = require('url')
local Error = require('core').Error

-- merge tables
local function merge(...)
  local args = {...}
  local first = args[1] or {}
  for i,t in pairs(args) do
    if i ~= 1 and t then
      for k, v in pairs(t) do
        first[k] = v
      end
    end
  end

  return first
end

local function proxy(uri, host, callback)
  local options = url.parse(uri)
  local proto = http

  if options.protocol == 'https' then
    proto = https
  end

  options.method = 'CONNECT'
  options.path = host
  options.headers = {
    ['connection'] = 'keep-alive',
  }

  local req
  req = proto.request(options, function(response)
    if response.status_code == 200 then
      req.socket:removeAllListeners()
      callback(nil, req.socket)
    else
      callback(Error:new('Proxy Error'))
    end
  end)
  req:once('error', callback)
  req:done()
end

local function request(options, callback)
  local parsed = url.parse(options.url)
  local opts = merge({}, options, parsed)
  local proto = http
  local port = 80

  if parsed.protocol == 'https' then
    proto = https
    port = 443
  end

  if parsed.port then
    port = parsed.port
  end

  local function perform(proto, opts, callback)
    local client = proto.request(opts, callback)
    client:done(opts.body)
  end

  if opts.proxy then
    proxy(opts.proxy, parsed.host .. ':' .. port, function(err, socket)
      if err then
        return callback(err)
      end
      opts.socket = socket
      perform(proto, opts, callback)
    end)
  else
    perform(proto, opts, callback)
  end
end

local exports = {}
exports.proxy = proxy
exports.request = request
return exports
