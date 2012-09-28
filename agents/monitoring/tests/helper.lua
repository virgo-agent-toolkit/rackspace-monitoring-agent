local spawn = require('childprocess').spawn

function runner(name)
  return spawn('python', {'agents/monitoring/runner.py', name})
end

local exports = {}
exports.runner = runner
return exports
