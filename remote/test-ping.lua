local runCheck = require('./index')
require('tap')(function (test)
  test("Ping localhost IPv4", function (expect)
    runCheck({
      id = 45,
      target = "localhost",
      module = "ping",
      resolver = "IPv4",
      timeout = 20000,
    }, {
      count = 10,
      delay = 100,
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
    end))
  end)

  test("Ping localhost IPv6", function (expect)
    runCheck({
      id = 46,
      target = "localhost",
      module = "ping",
      resolver = "IPv6",
      timeout = 20000,
    }, {
      count = 10,
      delay = 100,
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
    end))
  end)

  test("Ping luvit.io", function (expect)
    runCheck({
      id = 44,
      target = "luvit.io",
      module = "ping",
      timeout = 20000,
    }, {
      count = 10,
      delay = 100,
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
    end))
  end)

  test("Ping luvit.io ipv4 only", function (expect)
    runCheck({
      id = 44,
      target = "luvit.io",
      module = "ping",
      resolver = "IPv4",
      timeout = 20000,
    }, {
      count = 5,
      delay = 100,
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
    end))
  end)

  test("Ping luvit.io ipv6 only", function (expect)
    runCheck({
      id = 44,
      target = "luvit.io",
      module = "ping",
      resolver = "IPv6",
      timeout = 20000,
    }, {
      count = 5,
      delay = 100,
    }, expect(function (err, data)
      p(err, data)
      assert(not err, err)
    end))
  end)

end)
