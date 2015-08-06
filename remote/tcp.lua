local uv = require('uv')
local connect = require('coro-net').connect
local tlsWrap = require('coro-tls').wrap
local rex = require('rex')

local function getaddrinfo(host, port, family)
  local thread = coroutine.running()
  uv.getaddrinfo(host, port, {
    socktype = "stream",
    family = family,
  }, function (err, results)
    if err then
      return assert(coroutine.resume(thread, nil, err .. ": while looking up '" .. host .. "'"))
    end
    return assert(coroutine.resume(thread, results[1].addr, results[1].port))
  end)
  return coroutine.yield()
end


--[[------------------------------- Attributes ---------------------------------
target: String
  hostname or ip address
timeout: Uint32
  timeout in ms
--------------------------------- Config Params --------------------------------
port: Whole number (may be zero padded) / Integer between 1-65535 inclusive
  Port number
banner_match: Optional / String between 1 and 255 characters long
  Banner match regex.
body_match: Optional / String between 1 and 255 characters long
  Body match regex. Key/Values are captured when matches are specified within
  the regex. Note: Maximum body size 1024 bytes.
send_body: Optional / String between 1 and 1024 characters long
  Send a body. If a banner is provided the body is sent after the banner is
  verified.
ssl: Optional / Boolean
 Enable SSL
------------------------------------- Metrics ----------------------------------
banner: String
  The string sent from the server on connect.
banner_match: String
  The matched string from the banner_match regular expression specified during
  check creation.
duration: Uint32
  The time took to finish executing the check in milliseconds.
tt_connect: Uint32
  The time to connect measured in milliseconds.
tt_firstbyte: Uint32
  The time to first byte measured in milliseconds.
----------------------------------------------------------------------------]]--
return function (attributes, config, register, set)
  local start = uv.now()
  local body, banner
  local tt_firstbyte

  -- Resolve hostname and record time spent
  local ip, port = assert(getaddrinfo(attributes.target, config.port, attributes.family))
  set("tt_resolve", uv.now() - start)
  set("ip", ip)
  set("port", port)

  -- Connect to TCP port and record time spent
  local read, write, socket = assert(connect {
    host = ip,
    port = port
  })
  set("tt_connect", uv.now() - start)
  register(socket)

  if config.ssl then
    read, write = tlsWrap(read, write, {})
    set("tt_ssl", uv.now() - start)
  end

  -- Optionally read banner if banner_match is requested
  if config.banner_match then
    body = ""
    while true do
      local chunk = assert(read(), "could not read banner")
      if not tt_firstbyte then
        tt_firstbyte = uv.now() - start
        set("tt_firstbyte", tt_firstbyte)
      end
      local i = chunk:find("\n")
      if i then
        banner = body .. chunk:sub(1, i)
        body = chunk:sub(i + 1)
        break
      elseif #body > 1024 then
        banner = body:sub(1, 1024)
        body = body:sub(1025)
        break
      else
        body = body .. chunk
      end
    end
    set("banner", banner)
    set("banner_match", rex.match(banner, config.banner_match))
  end

  -- Optionally write send_body if requested
  if config.send_body then
    write(config.send_body)
    set("tt_write", uv.now() - start)
  end

  -- Optionally read body is body_match is requested
  if config.body_match then
    body = body or ""
    while true do
      local chunk = read()
      if not chunk then break end
      if not tt_firstbyte then
        tt_firstbyte = uv.now() - start
        set("tt_firstbyte", tt_firstbyte)
      end
      body = body .. chunk
      if #body > 1024 then
        body = body:sub(1, 1024)
        break
      end
    end
    set("body", body)
    set("body_match", rex.match(body, config.body_match))
  end

  set("duration", uv.now() - start)

end
