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
local debugm = require('debug')
local fmt = require('string').format

local MonitoringAgent = require('./agent').Agent
local Setup = require('./setup').Setup
local constants = require('./util/constants')
local protocolConnection = require('/protocol/virgo_connection')
local agentClient = require('/client/virgo_client')
local connectionStream = require('/client/virgo_connection_stream')

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
  .alias({['p'] = 'pidfile'})
  .alias({['d'] = 'debug'})
  .describe("u", "setup")
  .alias({['u'] = 'setup'})
  .describe("U", "username")
  .alias({['U'] = 'username'})
  .describe("K", "apikey")
  .alias({['K'] = 'apikey'})
  .argv("idonhU:K:e:x:p:c:s:n:k:u")

local Entry = {}

function Entry.run()
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

  options.configFile = argv.args.c or constants.DEFAULT_CONFIG_PATH

  if argv.args.p then
    options.pidFile = argv.args.p
  end

  if argv.args.i then
    options.tls = {
      rejectUnauthorized = false,
      ca = require('./certs').caCertsDebug
    }
  end

  if argv.args.e then
    local mod = require(argv.args.e)
    return mod.run(argv.args)
  end

  local types = {}
  types.ProtocolConnection = protocolConnection
  types.AgentClient = agentClient
  types.ConnectionStream = connectionStream

  -- hacks to make monitoring specific config files compatible with a generic agent.lua
  virgo.config['endpoints'] = virgo.config['monitoring_endpoints']
  virgo.config['upgrade'] = virgo.config['monitoring_upgrade']
  virgo.config['id'] = virgo.config['monitoring_id']
  virgo.config['token'] = virgo.config['monitoring_token']
  virgo.config['guid'] = virgo.config['monitoring_guid']
  virgo.config['query_endpoints'] = virgo.config['monitoring_query_endpoints']
  virgo.config['snet_region'] = virgo.config['monitoring_snet_region']
  
  local agent = MonitoringAgent:new(options, types)

  if not argv.args.u then
    return agent:start(options)
  end

  Setup:new(argv, options.configFile, agent):run()
end

return Entry
