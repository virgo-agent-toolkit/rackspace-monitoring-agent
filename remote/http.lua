local uv = require('uv')
local parseUrl = require('url').parse
local connect = require('coro-net').connect
local tlsWrap = require('coro-tls').wrap
local rex = require('rex')
local getaddrinfo = require('./utils').getaddrinfo
local httpCodec = require('http-codec')
local wrapper = require('coro-wrapper')
local httpAuth = require('./http-auth')
local os = require('os')

local function parseProps(data, string)
  for key, value in string:gmatch('([^ ";=]+)="([^"]+)"') do
    data[key] = value
  end
  for key, value in string:gmatch('([^ ";=]+)=([^ ";=]+)') do
    data[key] = value
  end
end

local function readBody(read)
  local body = ""
  for chunk in read do
    if not chunk then return end
    if #chunk == 0 then return body end
    body = body .. chunk
  end
end

local months = {
  Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
  Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12,
}
local function parseDate(date)
  -- parses dates like: Apr 28 15:31:07 2016 GMT
  local pattern = "(%a+) (%d+) (%d+):(%d+):(%d+) (%d+) (%a+)"
  local month, day, hour, min, sec, year, tz = date:match(pattern)
  month = months[month]
  -- TODO: account for timezone to get accurate timestamp
  return os.time({
    year = year,
    month = month,
    day = day,
    hour = hour,
    min = min,
    sec = sec
  }), tz
end


--[[------------------------------- Attributes ---------------------------------
target: String
  hostname or ip address
timeout: Uint32
  timeout in ms
--------------------------------- Config Params --------------------------------
url: URL / String between 1 and 8096 characters long
 	Target URL
auth_password: Optional / String between 1 and 255 characters long
 	Optional auth password
auth_user: Optional / String between 1 and 255 characters long
 	Optional auth user
body: Optional / String between 1 and 255 characters long
 	Body match regular expression (body is limited to 100k)
body_matches: Optional / Hash
  Body match regular expressions (body is limited to 100k, matches are truncated
    to 80 characters)
  Hash [String,String between 1 and 50 characters long,String matching the regex
    /^[-_ a-z0-9]+$/i:String,String between 1 and 255 characters long]
  Array or object with number of items between 0 and 4
follow_redirects: Optional / Boolean
 	Follow redirects (default: true)
headers: Optional / Hash
  Arbitrary headers which are sent with the request.
  Hash [String between 1 and 50 characters : String between 1 and 50 characters]
  Array or object with number of items between 0 and 10.
  A value which is not one of: content-length, user-agent, host, connection,
    keep-alive, transfer-encoding, upgrade
method: Optional / String / One of (HEAD, GET, POST, PUT, DELETE, INFO)
 	HTTP method (default: GET)
payload: Optional / String between 0 and 1024 characters long
  Specify a request body (limited to 1024 characters). If following a redirect,
  payload will only be sent to first location
------------------------------------- Metrics ----------------------------------
body_match: String
	The string representing the body match specified in a remote.http check.
body_match_one: String
  The string representing a single body_matches value specified in a remote.http
  check. This metrics are only present when using a body_matches option. one is
  the actual key you have specified for the body_matches option.
body_match_two: String
  The string representing a single body_matches value specified in a remote.http
  check. This metrics are only present when using a body_matches option. two is
  the actual key you have specified for the body_matches option.
bytes: Int32
  The number of bytes returned from a response payload.
cert_end: Uint32
  The absolute timestamp in seconds for the certificate expiration. This is only
  available when performing a check on an HTTPS server.
cert_end_in: Int32
  The relative timestamp in seconds til certification expiration. This is only
  available when performing a check on an HTTPS server.
cert_error: String
  A string describing a certificate error in our validation. This is only
  available when performing a check on an HTTPS server.
cert_issuer: String
  The issue string for the certificate. This is only available when performing a
  check on an HTTPS server.
cert_start: Uint32
  The absolute timestamp of the issue of the certificate. This is only available
  when performing a check on an HTTPS server.
cert_subject: String
  The subject of the certificate. This is only available when performing a check
  on an HTTPS server.
cert_subject_alternative_names: String
  The alternative name for the subject of the certificate. This is only
  available when performing a check on an HTTPS server.
code: String
  The status code returned.
duration: Uint32
  The time took to finish executing the check in milliseconds.
truncated: Uint32
  The number of bytes that the result was truncated by.
tt_connect: Uint32
  The time to connect measured in milliseconds.
tt_firstbyte: Uint32
  The time to first byte measured in milliseconds.
----------------------------------------------------------------------------]]--
return function (attributes, config, register, set)
  local start = uv.now()
  local body
  local read, write, socket, req, res

  local redirects_left = config.follow_redirects and 100 or 0
  local cookies = {}

  local function request(urlString, authProps)

    local url = parseUrl(urlString, true)

    -- Get host and ip from url, fallback to attributes
    local ssl = url.protocol == "https"
    local port = tonumber(url.port) or ssl and 443 or 80
    local host = url.hostname or attributes.target
    -- Resolve hostname and record time spent
    local ip = assert(getaddrinfo(host, port, attributes.family))
    set("tt_resolve", uv.now() - start)
    set("ip", ip)
    set("port", port)

    -- Connect to TCP port and record time spent
    read, write, socket = assert(connect {
      host = ip,
      port = port
    })
    set("tt_connect", uv.now() - start)
    register(socket)

    if ssl then
      read, write, ssl = tlsWrap(read, write, {})
      set("tt_ssl", uv.now() - start)
      local cert = ssl:peer()
      local expires = parseDate(cert:notafter())
      set("cert_end", expires)
      set("cert_end_in", expires - os.time())
      set("cert_start", parseDate(cert:notbefore()))
      set("cert_issuer", tostring(cert:issuer()))
      set("cert_subject", tostring(cert:subject()))
      -- TODO: cert_subject_alternative_names
      -- TODO: cert_error
    end

    read = wrapper.reader(read, httpCodec.decoder())
    write = wrapper.writer(write, httpCodec.encoder())
    req =  {
      method = config.method or "GET",
      path = url.path,
      {"Host", url.host},
      {"User-Agent", "Rackspace Monitoring Agent"},
    }
    local cookieList = {}
    for key, value in pairs(cookies) do
      if value:match(" ") then
        value = '"' .. value .. '"'
      end
      cookieList[#cookieList + 1] = key .. '=' .. value
    end
    if #cookieList > 0 then
      req[#req + 1] = {"Cookie", table.concat(cookieList, ", ")}
    end

    if config.auth_user and config.auth_password then
      local auth = httpAuth(config.auth_user, config.auth_password, authProps)
      req[#req + 1] = {"Authorization", auth}
    end

    if config.payload then
      req[#req + 1] = {"Content-Length", #config.payload}
    end

    if config.headers then
      for key, value in pairs(config.headers) do
        req[#req + 1] = {key, value}
      end
    end
    -- p(req)
    write(req)
    if config.payload then
      write(config.payload)
    end
    write("")
    res = read()
    -- p(res)
    set("tt_firstbyte", uv.now() - start)
    set("code", res.code)

    if not authProps and tonumber(res.code) == 401 then
      for i = 1, #res do
        local name = res[i][1]:lower()
        if name == "set-cookie" then
          parseProps(cookies, res[i][2])
        elseif name == "www-authenticate" then
          local challenge = res[i][2]
          if challenge:match("^Digest ") then
            authProps = {
              method = req.method,
              uri = req.path,
              body = readBody(read)
            }
            parseProps(authProps, challenge)
          end
        end
      end
      if authProps then
        return request(urlString, authProps)
      end
    end
    if redirects_left > 0 and tonumber(res.code) == 301 and res.location then
      redirects_left = redirects_left - 1
      write()
      return request(res.location)
    end
  end

  request(config.url)

  body = readBody(read)
  -- p(body)

  local bytes = #body
  set("bytes", bytes)
  if bytes > 100000 then
    body = body:sub(1, 100000)
  end
  set("truncated", bytes - #body)

  if config.body then
    set("body_match", rex.match(body, config.body))
  end
  if config.body_matches then
    for key, reg in pairs(config.body_matches) do
      set("body_match_" .. key, rex.match(body, reg))
    end
  end


  -- TODO: finish HTTP check

  set("duration", uv.now() - start)

end
