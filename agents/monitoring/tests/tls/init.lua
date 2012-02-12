local tlsbinding = require('_tls')

exports = {}
no = {}

exports['test_secure_context'] = function(test, asserts)
  local sc = tlsbinding.secure_context()
  local err, res = pcall(sc.setKey, sc, "foooooooo")
  assert(err == false)
  sc:close()
  test.done()
end

return exports

