--[[
Copyright 2015 Rackspace

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

local luvi = require('luvi')
luvi.bundle.register('require', "deps/require.lua")
_G.require = require('require')("bundle:main.lua")

local function start(...)
  local async = require('async')
  local fs = require('fs')
  local logging = require('logging')

  local MonitoringAgent = require('./agent').Agent
  local constants = require('./constants')
  local Setup = require('./setup').Setup

  local agentClient = require('./client/virgo_client')
  local connectionStream = require('./client/virgo_connection_stream')
  local protocolConnection = require('./protocol/virgo_connection')

  local argv = require('options')
    .usage('Usage: ')
    .describe("i", "use insecure tls cert")
    .describe("i", "insecure")
    .describe("e", "entry module")
    .describe("x", "runner params (eg. check or hostinfo to run)")
    .describe("s", "state directory path")
    .describe("c", "config file path")
    .describe("j", "object conf.d path")
    .describe("p", "pid file path")
    .describe("o", "skip automatic upgrade")
    .describe("d", "enable debug logging")
    .alias({['o'] = 'no-upgrade'})
    .alias({['p'] = 'pidfile'})
    .alias({['j'] = 'confd'})
    .alias({['d'] = 'debug'})
    .describe("u", "setup")
    .alias({['u'] = 'setup'})
    .describe("U", "username")
    .alias({['U'] = 'username'})
    .describe("K", "apikey")
    .alias({['K'] = 'apikey'})
    .argv("idonhU:K:e:x:p:c:j:s:n:k:u")

  local function readConfig(path)
    local config, data
    config = {}
    data, err = fs.readFileSync(path)
    if err then print(err) ; os.exit(1) end
    for line in data:gmatch("[^\r\n]+") do
      local key, value = line:match("(%S+) (.*)")
      config[key] = value
    end
    return config
  end

  if argv.args.d then
    local log = logging.StdoutLogger:new({
      log_level = logging.LEVELS['everything']
    })
    logging.init(log)
  end

  local options = {}
  options.configFile = argv.args.c or constants:get('DEFAULT_CONFIG_PATH')

  if argv.args.p then
    options.pidFile = argv.args.p
  end

  if argv.args.e then
    local mod = require(argv.args.e)
    return mod.run(argv.args)
  end

  local types = {}
  types.ProtocolConnection = protocolConnection
  types.AgentClient = agentClient
  types.ConnectionStream = connectionStream

  virgo.config = readConfig(options.configFile)
  virgo.config['token'] = virgo.config['monitoring_token']
  options.config = virgo.config
  options.tls = { rejectUnauthorized = false }


  --virgo.config['endpoints'] = virgo.config['monitoring_endpoints']
  --virgo.config['upgrade'] = virgo.config['monitoring_upgrade']
  --virgo.config['id'] = virgo.config['monitoring_id']
  --virgo.config['guid'] = virgo.config['monitoring_guid']
  --virgo.config['query_endpoints'] = virgo.config['monitoring_query_endpoints']
  --virgo.config['snet_region'] = virgo.config['monitoring_snet_region']
  --virgo.config['proxy'] = virgo.config['monitoring_proxy_url']
  --virgo.config['insecure'] = virgo.config['monitoring_insecure']
  --virgo.config['debug'] = virgo.config['monitoring_debug']

  if argv.args.i or virgo.config['insecure'] == 'true' then
    options.tls = {
      rejectUnauthorized = false,
      ca = require('/certs').caCertsDebug
    }
  end

  options.proxy = process.env.HTTP_PROXY or process.env.HTTPS_PROXY
  if virgo.config['proxy'] then
    options.proxy = virgo.config['proxy']
  end

  options.upgrades_enabled = true
  if argv.args.o or virgo.config['upgrade'] == 'disabled' then
    options.upgrades_enabled = false
  end

  async.series({
  --  function(callback)
  --    if los.type() ~= 'win32' then
  --      local opts = {}
  --      opts.skip = (options.upgrades_enabled == false)
  --      upgrade.attempt(opts, function(err)
  --        if err then
  --          logging.log(logging.ERROR, fmt("Error upgrading: %s", tostring(err)))
  --        end
  --        callback()
  --      end)
  --    else
  --      --on windows the upgrade occurs right after the download as an external process
  --      callback()
  --    end
  --  end,
    function(callback)
      local agent = MonitoringAgent:new(options, types)
      if argv.args.u then
        Setup:new(argv, options.configFile, agent):run()
      else
        agent:start(options)
      end
      callback()
    end
  })
end

return require('luvit')(function(...)
  local options = {}
  options.version = require('./package').version
  options.pkg_name = "rackspace-monitoring-agent"
  options.paths = {}
  options.paths.persistent_dir = "/var/lib/rackspace-monitoring-agent"
  options.paths.exe_dir = "/var/lib/rackspace-monitoring-agent/exe"
  options.paths.config_dir = "/etc"
  options.paths.library_dir = "/usr/lib/rackspace-monitoring-agent"
  options.paths.runtime_dir = "/var/run/rackspace-monitoring-agent"
  require('virgo')(options)
  start(...)
end)
