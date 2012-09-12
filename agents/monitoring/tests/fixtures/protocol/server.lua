local net = require('net')
local JSON = require('json')
local fixtures = require('./')
local LineEmitter = require('line-emitter').LineEmitter
local table = require('table')
local tls = require('tls')
local timer = require('timer')
local string = require('string')
local math = require('math')
local table = require('table')
local http = require("http")
local url = require('url')

local ports = {50041, 50051, 50061}

local opts = {}
local function set_option(options, name, default)
  options[name] = process.env[string.upper(name)] or default
end

set_option(opts, "send_schedule_changed_initial", 2000)
set_option(opts, "send_schedule_changed_interval", 60000)
set_option(opts, "destroy_connection_jitter", 60000)
set_option(opts, "destroy_connection_base", 60000)
set_option(opts, "listen_ip", '127.0.0.1')
set_option(opts, "perform_client_disconnect", 'true')

set_option(opts, "rate_limit", 3000)
set_option(opts, "rate_limit_reset", 86400) -- Reset limit in 24 hours

local keyPem = [[
-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQDx3wdzpq2rvwm3Ucun1qAD/ClB+wW+RhR1nVix286QvaNqePAd
CAwwLL82NqXcVQRbQ4s95splQnwvjgkFdKVXFTjPKKJI5aV3wSRN61EBVPdYpCre
535yfG/uDysZFCnVQdnCZ1tnXAR8BirxCNjHqbVyIyBGjsNoNCEPb2R35QIDAQAB
AoGBAJNem9C4ftrFNGtQ2DB0Udz7uDuucepkErUy4MbFsc947GfENjDKJXr42Kx0
kYx09ImS1vUpeKpH3xiuhwqe7tm4FsCBg4TYqQle14oxxm7TNeBwwGC3OB7hiokb
aAjbPZ1hAuNs6ms3Ybvvj6Lmxzx42m8O5DXCG2/f+KMvaNUhAkEA/ekrOsWkNoW9
2n3m+msdVuxeek4B87EoTOtzCXb1dybIZUVv4J48VAiM43hhZHWZck2boD/hhwjC
M5NWd4oY6QJBAPPcgBVNdNZSZ8hR4ogI4nzwWrQhl9MRbqqtfOn2TK/tjMv10ALg
lPmn3SaPSNRPKD2hoLbFuHFERlcS79pbCZ0CQQChX3PuIna/gDitiJ8oQLOg7xEM
wk9TRiDK4kl2lnhjhe6PDpaQN4E4F0cTuwqLAoLHtrNWIcOAQvzKMrYdu1MhAkBm
Et3qDMnjDAs05lGT72QeN90/mPAcASf5eTTYGahv21cb6IBxM+AnwAPpqAAsHhYR
9h13Y7uYbaOjvuF23LRhAkBoI9eaSMn+l81WXOVUHnzh3ZwB4GuTyxMXXNOhuiFd
0z4LKAMh99Z4xQmqSoEkXsfM4KPpfhYjF/bwIcP5gOei
-----END RSA PRIVATE KEY-----
]]

local certPem = [[
-----BEGIN CERTIFICATE-----
MIIDXDCCAsWgAwIBAgIJAKL0UG+mRkSPMA0GCSqGSIb3DQEBBQUAMH0xCzAJBgNV
BAYTAlVLMRQwEgYDVQQIEwtBY2tuYWNrIEx0ZDETMBEGA1UEBxMKUmh5cyBKb25l
czEQMA4GA1UEChMHbm9kZS5qczEdMBsGA1UECxMUVGVzdCBUTFMgQ2VydGlmaWNh
dGUxEjAQBgNVBAMTCWxvY2FsaG9zdDAeFw0wOTExMTEwOTUyMjJaFw0yOTExMDYw
OTUyMjJaMH0xCzAJBgNVBAYTAlVLMRQwEgYDVQQIEwtBY2tuYWNrIEx0ZDETMBEG
A1UEBxMKUmh5cyBKb25lczEQMA4GA1UEChMHbm9kZS5qczEdMBsGA1UECxMUVGVz
dCBUTFMgQ2VydGlmaWNhdGUxEjAQBgNVBAMTCWxvY2FsaG9zdDCBnzANBgkqhkiG
9w0BAQEFAAOBjQAwgYkCgYEA8d8Hc6atq78Jt1HLp9agA/wpQfsFvkYUdZ1YsdvO
kL2janjwHQgMMCy/Njal3FUEW0OLPebKZUJ8L44JBXSlVxU4zyiiSOWld8EkTetR
AVT3WKQq3ud+cnxv7g8rGRQp1UHZwmdbZ1wEfAYq8QjYx6m1ciMgRo7DaDQhD29k
d+UCAwEAAaOB4zCB4DAdBgNVHQ4EFgQUL9miTJn+HKNuTmx/oMWlZP9cd4QwgbAG
A1UdIwSBqDCBpYAUL9miTJn+HKNuTmx/oMWlZP9cd4ShgYGkfzB9MQswCQYDVQQG
EwJVSzEUMBIGA1UECBMLQWNrbmFjayBMdGQxEzARBgNVBAcTClJoeXMgSm9uZXMx
EDAOBgNVBAoTB25vZGUuanMxHTAbBgNVBAsTFFRlc3QgVExTIENlcnRpZmljYXRl
MRIwEAYDVQQDEwlsb2NhbGhvc3SCCQCi9FBvpkZEjzAMBgNVHRMEBTADAQH/MA0G
CSqGSIb3DQEBBQUAA4GBADRXXA2xSUK5W1i3oLYWW6NEDVWkTQ9RveplyeS9MOkP
e7yPcpz0+O0ZDDrxR9chAiZ7fmdBBX1Tr+pIuCrG/Ud49SBqeS5aMJGVwiSd7o1n
dhU2Sz3Q60DwJEL1VenQHiVYlWWtqXBThe9ggqRPnCfsCRTP8qifKkjk45zWPcpN
-----END CERTIFICATE-----
]]

local options = {
  cert = certPem,
  key = keyPem
}

local respond = function(log, client, payload)
  local destroy = false

  -- skip responses to requests
  if payload.method == nil then
    return
  end

  local response_method = payload.method .. '.response'
  local response = JSON.parse(fixtures[response_method])
  local response_out = nil

  -- Handle rate limit logic
  client.rate_limit = client.rate_limit - 1
  if client.rate_limit <= 0 then
    response = JSON.parse(fixtures['rate-limiting']['rate-limit-error'])
    destroy = true
  end

  response.target = payload.source
  response.source = payload.target
  response.id = payload.id

  -- Print the payload. The p() is intentional, Ryan :D
  log("Sending response:")
  p(response)

  response_out = JSON.stringify(response)
  response_out:gsub("\n", " ")

  client:write(response_out .. '\n')

  if destroy == true then
    client:destroy()
  end

  return destroy
end

local send_schedule_changed = function(log, client)
  local request = fixtures['check_schedule.changed.request']

  log("Sending request:")
  p(JSON.parse(request))
  client:write(request .. '\n')
end

local function clear_timers(timer_ids)
  for k, v in pairs(timer_ids) do
    if v._closed ~= true then
      timer.clearTimer(v)
    end
  end
end

local function start_fixture_server(options, port)
  local log = function(...)
    print(port .. ": " .. ...)
  end

  local server = tls.createServer(options, function (client)
    local lineEmitter = LineEmitter:new()
    local destroyed = false
    local timers = {}

    client.rate_limit = opts.rate_limit
    client:pipe(lineEmitter)
    lineEmitter:on('data', function(line)
      local payload = JSON.parse(line)
      log("Got payload:")
      p(payload)
      destroyed = respond(log, client, payload)

      if destroyed == true then
        clear_timers(timers)
      end

    end)

    -- Reset rate limit counter
    timer.setTimeout(opts.rate_limit_reset, function()
      client.rate_limit = opts.rate_limit
    end)

    timer.setTimeout(opts.send_schedule_changed_initial, function()
      send_schedule_changed(log, client)
    end)

    table.insert(timers,
      timer.setInterval(opts.send_schedule_changed_interval, function()
        send_schedule_changed(log, client)
      end)
    )

    -- Disconnect the agent after some random number of seconds
    -- to exercise reconnect logic
    if opts.perform_client_disconnect == 'true' then
      local disconnect_time = opts.destroy_connection_base + math.floor(math.random() * opts.destroy_connection_jitter)
      timer.setTimeout(disconnect_time, function()
        log("Destroying connection after " .. disconnect_time .. "ms connected")
        client:destroy()
      end)
    end
  end):listen(port, opts.listen_ip)

  return server
end

-- There is no cleanup code for the server here as the process for exiting is
-- to just ctrl+c the runner or kill the process.
for k, v in pairs(ports) do
  start_fixture_server(options, v)
  print("TCP echo server listening on port " .. v)
end

