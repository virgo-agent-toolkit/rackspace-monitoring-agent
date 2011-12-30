local VUtils = require('virgo-utils')
local Entry = {}

function Entry.run()
  local opts = VUtils.getopt(process.argv, '')

  if opts.t then
    require('./test').run()
    return
  end

  require('./monitoring-agent').run()
end

return Entry
