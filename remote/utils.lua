local uv = require('uv')
function exports.getaddrinfo(host, port, family)
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
