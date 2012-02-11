local tlsbinding = require('_tls')

exports = {}
no = {}

exports['test_secure_context'] = function(test, asserts)
  local sc = tlsbinding.secure_context()
  sc:close()
  test.done()
end

return exports

