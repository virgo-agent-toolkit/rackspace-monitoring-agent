local Test = {}
local async = require('lua-async')

function Test.run()
  async.forEach({1,2,3}, function(k, callback)
    print(k)
    callback()
  end, function()
    print('Done')
  end)
end

return Test
