local runCheck = require('./index')
require('tap')(function (test)

  test("TCP port 80", function (expect)
    runCheck({
      id = 42,
      target = "howtonode.org",
      family = "inet4",
      module = "tcp",
      timeout = 1000,
    }, {
      port = 80,
      send_body = "GET / HTTP/1.0\r\n" ..
                  "Host: howtonode.org\r\n\r\n",
      body_match = "^HTTP/1\\.[10] 200 OK"
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
      assert(data.id)
      assert(data.body)
      assert(data.body:match("How To Node %- NodeJS"))
      assert(data.body_match)
      assert(data.tt_resolve)
      assert(data.tt_connect)
      assert(data.tt_write)
      assert(data.tt_firstbyte)
      assert(data.duration)
    end))
  end)

  test("TCP port 443", function (expect)
    runCheck({
      id = 43,
      target = "creationix.com",
      family = "inet4",
      -- family = "inet6", -- Need ISP with ipv6 to test
      module = "tcp",
      timeout = 1000,
    }, {
      port = 443,
      ssl = true,
      -- port = 80,
      send_body = "GET / HTTP/1.0\r\n" ..
                  "Host: creationix.com\r\n\r\n",
      body_match = "^HTTP/1\\.[10] 200 OK"
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
      assert(data.id)
      assert(data.body)
      assert(data.body:match("Creationix School of Innovation"))
      assert(data.body_match)
      assert(data.tt_resolve)
      assert(data.tt_connect)
      assert(data.tt_ssl)
      assert(data.tt_write)
      assert(data.tt_firstbyte)
      assert(data.duration)
    end))
  end)

  test("TCP port 22", function (expect)
    runCheck({
      id = 43,
      target = "127.0.0.1",
      family = "inet4",
      module = "tcp",
      timeout = 2000,
    }, {
      port = 22,
      banner_match = "SSH",
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
      assert(data.id)
      assert(data.banner)
      assert(data.banner:match("OpenSSH"))
      assert(data.banner_match)
      assert(data.tt_resolve)
      assert(data.tt_connect)
      assert(data.tt_firstbyte)
      assert(data.duration)
    end))
  end)

end)
