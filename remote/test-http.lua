local runCheck = require('./index')
require('tap')(function (test)

  test("HTTP", function (expect)
    runCheck({
      id = 30,
      target = "luvit.io",
      module = "http",
      timeout = 10000,
    }, {
      url = "http://luvit.io/",
      body_matches = {
        title = "title>([^<]+)",
      },
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
      assert(data.code == 301)
      assert(data.id == 30)
      assert(data.bytes > 0 and data.bytes < 1024)
      assert(data.port == 80)
      assert(data.body_match_title == "301 Moved Permanently")
      assert(data.ip == "23.253.227.83")
      assert(data.tt_firstbyte)
      assert(data.duration)
    end))
  end)

  test("HTTPS", function (expect)
    runCheck({
      id = 31,
      target = "luvit.io",
      module = "http",
      timeout = 10000,
    }, {
      url = "https://luvit.io/",
      body = "title>([^<]+)",
      body_matches = {
        title = "title>([^<]+)",
      },
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
      assert(data.code == 200)
      assert(data.id == 31)
      assert(data.bytes > 1024)
      assert(data.port == 443)
      assert(data.body_match_title == "Luvit.io")
      assert(data.body_match == "Luvit.io")
      assert(data.ip == "23.253.227.83")
      assert(data.tt_firstbyte)
      assert(data.tt_ssl)
      assert(data.duration)
      assert(data.cert_end)
      assert(data.cert_end_in)
      assert(data.cert_start)
      assert(data.cert_issuer)
      assert(data.cert_subject)
    end))
  end)

  test("Basic Auth", function (expect)
    runCheck({
      id = 32,
      target = "httpbin.org",
      module = "http",
      timeout = 10000,
    }, {
      url = "http://httpbin.org/basic-auth/creationix/iluvit",
      auth_user = "creationix",
      auth_password = "iluvit",
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
      assert(data.code == 200)
    end))
  end)

  test("HTTP Hidden Basic Auth", function (expect)
    runCheck({
      id = 33,
      target = "httpbin.org",
      module = "http",
      timeout = 10000,
    }, {
      url = "http://httpbin.org/hidden-basic-auth/creationix/iluvit",
      auth_user = "creationix",
      auth_password = "iluvit",
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
      assert(data.code == 200)
    end))
  end)

  test("Digest Auth", function (expect)
    runCheck({
      id = 34,
      target = "httpbin.org",
      module = "http",
      timeout = 10000,
    }, {
      url = "http://httpbin.org/digest-auth/auth/creationix/iluvit",
      auth_user = "creationix",
      auth_password = "iluvit",
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
      assert(data.code == 200)
    end))
  end)

  test("Digest Auth-int", function (expect)
    runCheck({
      id = 35,
      target = "httpbin.org",
      module = "http",
      timeout = 10000,
    }, {
      url = "http://httpbin.org/digest-auth/auth-int/creationix/iluvit",
      auth_user = "creationix",
      auth_password = "iluvit",
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
      assert(data.code == 200)
    end))
  end)

  test("Digest Auth other", function (expect)
    runCheck({
      id = 36,
      target = "httpbin.org",
      module = "http",
      timeout = 10000,
    }, {
      url = "http://httpbin.org/digest-auth/other/creationix/iluvit",
      auth_user = "creationix",
      auth_password = "iluvit",
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
      assert(data.code == 200)
    end))
  end)

  test("custom headers", function (expect)
    runCheck({
      id = 37,
      target = "httpbin.org",
      module = "http",
      timeout = 10000,
    }, {
      url = "http://httpbin.org/headers",
      headers = {
        ["X-Custom-Header"]= "yes!",
      },
      body = '"X-Custom-Header": *"([^"]*)"',
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
      assert(data.code == 200)
      assert(data.body_match == 'yes!')
    end))
  end)

  test("post body", function (expect)
    runCheck({
      id = 38,
      target = "httpbin.org",
      module = "http",
      timeout = 10000,
    }, {
      method = "POST",
      url = "http://httpbin.org/post",
      payload = "Hello World\n",
      body = '"data": *"([^"]*)"',
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
      assert(data.code == 200)
      assert(data.body_match == 'Hello World\\n')
    end))
  end)

end)
