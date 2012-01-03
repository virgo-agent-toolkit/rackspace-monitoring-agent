local Entry = {}

local argv = require("options")
  :usage("Usage: ")
  :describe("e", "entry module")
  :argv("he:")

function Entry.run()
  local mod = argv.args.e or 'monitoring-agent'
  mod = './' .. mod
  require(mod).run()
end

return Entry
