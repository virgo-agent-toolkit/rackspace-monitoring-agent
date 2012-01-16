local logging = require('logging')

local Entry = {}

local argv = require("options")
  :usage("Usage: ")
  :describe("e", "entry module")
  :argv("he:")

function Entry.run()
  local mod = argv.args.e or 'monitoring-agent'
  mod = './' .. mod

  logging.log(logging.INFO, 'Running Module ' .. mod)

  local err, msg = pcall(function()
    require(mod).run()
  end)

  if err == false then
    logging.log(logging.ERR, msg)
  end
end

return Entry
