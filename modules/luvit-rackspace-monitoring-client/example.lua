local Client = require('rackspace-monitoring').Client

local client = Client:new('', '', nil)
client.entities.get(function(err, results)
  if err then
    p(err)
    return
  end
  p(results)
end)
