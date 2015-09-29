-- TODO: publish this to lit for others to use

local base64 = require('openssl').base64
local digest = require('openssl').digest.digest

-- For HTTP basic auth, simply omit authProps entirely.
-- For HTTP Digest auth, pass in pre-parsed auth properties
-- authProps accepts the following keys:
--   method (GET, POST, PUT, etc...)
--   uri (example /dir/index.html)
--   realm (example user@example.com)
--   nonce (server-generated random value)
--   opaque - (server-generated opaque value)
--   qop - optional(auth or auth-int)
--   algorithm - optional(MD5 or MD5-sess)
--   body optional(entitybody for MD5-sess)
return function (username, password, authProps)
  if not authProps then
    return "Basic " ..
      base64(username .. ":" .. password):gsub("\n", "")
  end

  local nc = "00000001"
  local cnonce = string.format("%08x", math.random(0x100000000))

  local ha1, ha2, response

  -- Calculate HA1
  ha1 = digest("md5", table.concat({
    username, authProps.realm, password
  }, ":"))
  if authProps.algorithm == "MD5-sess" then
    ha1 = digest("md5", table.concat({
      ha1, authProps.nonce, cnonce
    }, ":"))
  end

  -- Calculate HA2
  if authProps.qop == "auth-int" then
    ha2 = digest("md5", table.concat({
      authProps.method, authProps.uri,
      digest("md5", authProps.body)
    }, ":"))
  else
    if authProps.qop then authProps.qop = "auth" end
    ha2 = digest("md5", table.concat({
      authProps.method, authProps.uri
    }, ":"))
  end

  -- Calculate Response
  if authProps.qop then
    response = digest("md5", table.concat({
      ha1, authProps.nonce, nc, cnonce, authProps.qop, ha2,
    }, ":"))
  else
    response = digest("md5", table.concat({
      ha1, authProps.nonce, ha2
    }, ":"))
  end

  -- Form Authorization header value
  return string.format('Digest ' ..
    ' username="%s", realm="%s", nonce="%s", uri="%s",' ..
    ' response="%s", opaque="%s", qop=%s, nc=%s, cnonce="%s"',
    username, authProps.realm, authProps.nonce, authProps.uri,
    response, authProps.opaque, authProps.qop, nc, cnonce)

end
