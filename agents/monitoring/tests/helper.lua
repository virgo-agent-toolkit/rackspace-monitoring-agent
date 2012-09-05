local spawn = require('childprocess').spawn

function runner(name)
  return spawn('python', {'agents/monitoring/runner', name})
end

local exports = {}
exports.runner = runner
return exports
