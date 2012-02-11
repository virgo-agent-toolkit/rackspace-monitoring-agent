local tlsbinding = require('_tls')

exports = {}
no = {}

exports['test_secure_context'] = function(test, asserts)
  local sc = tlsbinding.secure_context()
  p(sc)
  p('fooooooo')
  sc:setKey("foooooooo")
  p('doing close')
  sc:close()
  p('calling done')
  test.done()
end

return exports

