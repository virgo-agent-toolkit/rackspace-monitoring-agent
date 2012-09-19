--[[
Copyright 2012 Rackspace

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local logging = require('logging')

local Entry = {}

local argv = require("options")
  .usage('Usage: ')
  .describe("i", "use insecure tls cert")
  .describe("i", "insecure")
  .describe("e", "entry module")
  .describe("x", "check to run")
  .describe("s", "state directory path")
  .describe("c", "config file path")
  .describe("p", "pid file path")
  .describe("o", "skip automatic upgrade")
  .describe("d", "enable debug logging")
  .alias({['o'] = 'no-upgrade'})
  .alias({['d'] = 'debug'})
  .describe("u", "setup")
  .alias({['u'] = 'setup'})
  .describe("n", "username")
  .alias({['n'] = 'username'})
  .describe("k", "apikey")
  .alias({['k'] = 'apikey'})
  .argv("idonhe:x:p:c:s:n:k:u")

function Entry.run()
  local mod = argv.args.e and argv.args.e or 'default'
  mod = './modules/monitoring/' .. mod

  if argv.args.d then
    logging.set_level(logging.EVERYTHING)
  else
    logging.set_level(logging.INFO)
  end
  logging.debugf('Running Module %s', mod)

  local err, msg = pcall(function()
    require(mod).run(argv.args)
  end)

  if err == false then
    logging.error(msg)
    process.exit(1)
  end
end

return Entry
