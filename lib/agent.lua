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

local MonitoringAgent = require('../agent').Agent
local Setup = require('../setup').Setup
local agentClient = require('/client/virgo_client')
local async = require('async')
local connectionStream = require('/client/virgo_connection_stream')
local constants = require('/constants')
local core = require('core')
local debugger = require('virgo_debugger')
local debugm = require('debug')
local fmt = require('string').format
local logging = require('logging')
local misc = require('/base/util/misc')
local protocolConnection = require('/protocol/virgo_connection')
local upgrade = require('/base/client/upgrade')
local vutils = require('virgo_utils')
local os = require('os')

local argv = require("options")
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

local Agent = core.Object:extend()

function Agent.run()
  virgo_crash.init(vutils.getCrashPath())

  if argv.args.d then
    logging.set_level(logging.EVERYTHING)
  else
    logging.set_level(logging.INFO)
  end

  if argv.args.crash then
    return virgo.force_crash()
  end

  local options = {}

  if argv.args.s then
    options.stateDirectory = argv.args.s
  end

  if argv.args.j then
    options.confdDir = argv.args.j
  end

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

  virgo.config = virgo.config or {}
  virgo.config['endpoints'] = virgo.config['monitoring_endpoints']
  virgo.config['upgrade'] = virgo.config['monitoring_upgrade']
  virgo.config['id'] = virgo.config['monitoring_id']
  virgo.config['token'] = virgo.config['monitoring_token']
  virgo.config['guid'] = virgo.config['monitoring_guid']
  virgo.config['query_endpoints'] = virgo.config['monitoring_query_endpoints']
  virgo.config['snet_region'] = virgo.config['monitoring_snet_region']
  virgo.config['proxy'] = virgo.config['monitoring_proxy_url']
  virgo.config['insecure'] = virgo.config['monitoring_insecure']
  virgo.config['debug'] = virgo.config['monitoring_debug']

  -- trim options
  virgo.config['token'] = misc.trim(virgo.config['token'])
  virgo.config['id'] = misc.trim(virgo.config['id'])

  if argv.args.d or virgo.config['debug'] == 'true' then
    logging.set_level(logging.EVERYTHING)
  else
    logging.set_level(logging.INFO)
  end

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
    function(callback)
      if os.type() ~= 'win32' then
        local opts = {}
        opts.skip = (options.upgrades_enabled == false)
        upgrade.attempt(opts, function(err)
          if err then
            logging.log(logging.ERROR, fmt("Error upgrading: %s", tostring(err)))
          end
          callback()
        end)
      else
        --on windows the upgrade occurs right after the download as an external process
        callback()
      end
    end,
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

return function(features)
  return Agent:new()
end
