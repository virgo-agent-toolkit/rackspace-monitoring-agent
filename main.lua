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
local los = require('los')
local path = require('path')

local function start(...)
  local async = require('async')
  local fs = require('fs')
  local logging = require('logging')
  local uv = require('uv')

  local MonitoringAgent = require('./agent').Agent
  local Setup = require('./setup').Setup
  local WinSvcWrap = require('./winsvcwrap')
  local agentClient = require('./client/virgo_client')
  local certs = require('./certs')
  local connectionStream = require('./client/virgo_connection_stream')
  local constants = require('./constants')
  local protocolConnection = require('./protocol/virgo_connection')
  local upgrade = require('virgo/client/upgrade')

  local log_level

  local gcCollect = uv.new_prepare()
  uv.prepare_start(gcCollect, function() collectgarbage('step') end)
  uv.unref(gcCollect)

  process:on('sighup', function()
    logging.info('Received SIGHUP. Rotating logs.')
    logging.rotate()
  end)

  local argv = require('options')
    .describe("i", "use insecure tls cert")
    .describe("e", "entry module")
    .describe("x", "runner params (eg. check or hostinfo to run)")
    .describe("s", "state directory path")
    .describe("c", "config file path")
    .describe("j", "object conf.d path")
    .describe("p", "pid file path")
    .describe("z", "lock file path")
    .describe("o", "skip automatic upgrade")
    .describe("d", "enable debug logging")
    .describe("l", "log file path")
    .describe("w", "windows service command: install, delete, start, stop, status")
    .alias({['w'] = 'winsvc'})
    .alias({['o'] = 'no-upgrade'})
    .alias({['p'] = 'pidfile'})
    .alias({['j'] = 'confd'})
    .alias({['l'] = 'logfile'})
    .describe("l", "logfile")
    .alias({['d'] = 'debug'})
    .describe("u", "setup")
    .alias({['u'] = 'setup'})
    .describe("U", "username")
    .alias({['U'] = 'username'})
    .describe("K", "apikey")
    .alias({['K'] = 'apikey'})
    .argv("idonhl:U:K:e:x:p:c:j:s:n:k:ul:z:w:")

  argv.usage('Usage: ' .. argv.args['$0'] .. ' [options]')

  if argv.args.h then
    argv.showUsage("idonhU:K:e:x:p:c:j:s:n:k:ul:z:w:")
    process:exit(0)
  end

  local function readConfig(path)
    local config, data, err
    config = {}
    data, err = fs.readFileSync(path)
    if err then return {} end
    for line in data:gmatch("[^\r\n]+") do
      local key, value = line:match("(%S+) (.*)")
      config[key] = value
    end
    return config
  end

  if argv.args.w then
    -- set up windows service 
    if not WinSvcWrap then
      logging.log(logging.ERROR, "windows service module not loaded")
      process:exit(1)
    end
    if argv.args.w == 'install' then
      WinSvcWrap.SvcInstall(virgo.pkg_name, "Rackspace Monitoring Service", "Monitors this host", {args = {'-l', "\"" .. path.join(virgo_paths.VIRGO_PATH_PERSISTENT_DIR, "agent.log") .. "\""}})
    elseif argv.args.w == 'delete' then
      WinSvcWrap.SvcDelete(virgo.pkg_name)
    elseif argv.args.w == 'start' then
      WinSvcWrap.SvcStart(virgo.pkg_name)
    elseif argv.args.w == 'stop' then
      WinSvcWrap.SvcStop(virgo.pkg_name)
    else
      -- write something here....
    end
    return
  end

  if argv.args.d or argv.args.u then
    log_level = logging.LEVELS['everything']
  end

  -- Setup Logging
  logging.init(logging.StdoutFileLogger:new({
    log_level = log_level,
    path = argv.args.l
  }))

  local options = {}
  options.configFile = argv.args.c or constants:get('DEFAULT_CONFIG_PATH')
  if argv.args.p then
    options.pidFile = argv.args.p
  end

  if argv.args.z then
    options.lockFile = argv.args.z
  end

  if argv.args.e then
    local mod = require('./runners/' .. argv.args.e)
    return mod.run(argv.args)
  end

  logging.log(logging.INFO, string.format("Using config file: %s", options.configFile))

  local types = {}
  types.ProtocolConnection = protocolConnection
  types.AgentClient = agentClient
  types.ConnectionStream = connectionStream

  if not argv.args.x then
    virgo.config = readConfig(options.configFile) or {}
    options.config = virgo.config
  end

  options.tls = {}
  options.tls.rejectUnauthorized = true
  options.tls.ca = certs.caCerts

  virgo.config['token'] = virgo.config['monitoring_token']
  virgo.config['endpoints'] = virgo.config['monitoring_endpoints']
  virgo.config['upgrade'] = virgo.config['monitoring_upgrade']
  virgo.config['id'] = virgo.config['monitoring_id']
  virgo.config['guid'] = virgo.config['monitoring_guid']
  virgo.config['query_endpoints'] = virgo.config['monitoring_query_endpoints']
  virgo.config['snet_region'] = virgo.config['monitoring_snet_region']
  virgo.config['proxy'] = virgo.config['monitoring_proxy_url']
  virgo.config['insecure'] = virgo.config['monitoring_insecure']
  virgo.config['debug'] = virgo.config['monitoring_debug']

  if argv.args.i or virgo.config['insecure'] == 'true' then
    options.tls.ca = certs.caCertsDebug
  end

  options.proxy = process.env.HTTP_PROXY or process.env.HTTPS_PROXY
  if virgo.config['proxy'] then
    options.proxy = virgo.config['proxy']
  end

  options.upgrades_enabled = true
  if argv.args.o or virgo.config['upgrade'] == 'disabled' then
    options.upgrades_enabled = false
  end

  local agent = MonitoringAgent:new(options, types)
  if argv.args.u then
    Setup:new(argv, options.configFile, agent):run()
  else
    if los.type() == 'win32' then
      WinSvcWrap.tryRunAsService(virgo.pkg_name, function()
        agent:start(options)
      end) 
    else
      agent:start(options)
    end 
  end
end

return require('luvit')(function(...)
  local options = {}
  options.version = require('./package').version
  options.pkg_name = "rackspace-monitoring-agent"
  options.creator_name = "Rackspace Monitoring"
  options.long_pkg_name = options.creator_name .. " Agent"
  options.paths = {}
  if los.type() ~= 'win32' then
    options.paths.persistent_dir = "/var/lib/rackspace-monitoring-agent"
    options.paths.exe_dir = options.paths.persistent_dir .. "/exe"
    options.paths.config_dir = "/etc"
    options.paths.library_dir = "/usr/lib/rackspace-monitoring-agent"
    options.paths.runtime_dir = "/var/run/rackspace-monitoring-agent"
  else
    local winpaths = require('virgo/util/win_paths')
    options.paths.persistent_dir = path.join(winpaths.GetKnownFolderPath(winpaths.FOLDERID_ProgramData), options.creator_name)
    options.paths.exe_dir = path.join(options.paths.persistent_dir, "exe")
    options.paths.config_dir = path.join(options.paths.persistent_dir, "config")
    options.paths.library_dir = path.join(winpaths.GetKnownFolderPath(winpaths.FOLDERID_ProgramFiles), options.creator_name)
    options.paths.runtime_dir = options.paths.persistent_dir
  end
  options.paths.current_exe = args[0]
  require('virgo')(options, start)
end)
