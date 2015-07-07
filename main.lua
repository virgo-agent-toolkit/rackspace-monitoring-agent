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

local names = {}
names.pkg_name = "rackspace-monitoring-agent"
names.creator_name = "Rackspace Monitoring"
names.long_pkg_name = names.creator_name .. " Agent"


local function start(...)
  local logging = require('logging')
  local uv = require('uv')
  local openssl = require('openssl')

  local log_level
  local _, _, opensslVersion = openssl.version()

  local gcCollect = uv.new_prepare()
  uv.prepare_start(gcCollect, function() collectgarbage('step') end)
  uv.unref(gcCollect)

  local function detach()
    local spawn_exe = uv.exepath()
    local spawn_args = {}
    for i=1, #args do
      if args[i] ~= '-D' then
        table.insert(spawn_args, args[i])
      end
    end
    uv.spawn(spawn_exe, { args = spawn_args, detached = true }, function() end)
    os.exit(0)
  end

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
    .describe("D", "detach")
    .describe("l", "log file path")
    .describe("w", "windows service command: install, delete, start, stop, status")
    .describe("v", "version")
    .alias({['h'] = 'help'})
    .describe("h", 'help')
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
    .describe("v", "version")
    .alias({['v'] = 'version'})
    .describe("K", "apikey")
    .alias({['K'] = 'apikey'})
    .describe("D", "detach")
    .alias({['D'] = 'detach'})
    .describe("A", "auto create entity within setup")
    .alias({['A'] = 'auto-create-entity'})
    .argv("AidDonhl:U:K:e:x:p:c:j:s:n:k:uz:w:v")

  argv.usage('Usage: ' .. argv.args['$0'] .. ' [options]')

  if argv.args.h then
    argv.showUsage("idDonhl:U:K:e:x:p:c:j:s:n:k:uz:w:v")
    process:exit(0)
  end

  if argv.args.d or argv.args.u then
    log_level = logging.LEVELS['everything']
  end

  -- Setup Logging
  logging.init(logging.StdoutFileLogger:new({
    log_level = log_level,
    path = argv.args.l
  }))

  local function loadUnixSignals()
    process:on('sighup', function()
      logging.info('Received SIGHUP. Rotating logs.')
      logging.rotate()
    end)

    process:on('sigusr1', function()
      logging.info('Received SIGUSR1. Forcing GC.')
      collectgarbage()
      collectgarbage()
    end)

    process:on('sigusr2', function()
      local logLevel
      if logging.instance:getLogLevel() == logging.LEVELS['everything'] then
        logging.info('Received SIGUSR2. Setting info log level.')
        logLevel = logging.LEVELS['info']
      else
        logging.info('Received SIGUSR2. Setting debug log level.')
        logLevel = logging.LEVELS['everything']
      end
      logging.instance:setLogLevel(logLevel)
    end)
  end

  local _, err = pcall(function()
    local fs = require('fs')
    local MonitoringAgent = require('./agent').Agent
    local Setup = require('./setup').Setup
    local WinSvcWrap = require('virgo/winsvcwrap')
    local agentClient = require('./client/virgo_client')
    local certs = require('./certs')
    local connectionStream = require('./client/virgo_connection_stream')
    local constants = require('./constants')
    local protocolConnection = require('./protocol/virgo_connection')
    local luvi = require('luvi')
    local fmt = require('string').format

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

    if argv.args.v then
      print(fmt("%s (virgo %s, luvi %s, libuv %s, %s)",
        virgo.bundle_version, virgo.virgo_version, luvi.version, uv.version_string(),
        opensslVersion))
      return
    end

    if argv.args.D then
      return detach()
    end

    if argv.args.w then
      -- set up windows service 
      if not WinSvcWrap then
        logging.log(logging.ERROR, "windows service module not loaded")
        process:exit(1)
      end
      if argv.args.w == 'install' then
        WinSvcWrap.SvcInstall(names.long_pkg_name, "Rackspace Monitoring Service", "Monitors this host", {args = {'-l', "\"" .. path.join(virgo_paths.VIRGO_PATH_PERSISTENT_DIR, "log.txt") .. "\""}})
      elseif argv.args.w == 'delete' then
        WinSvcWrap.SvcDelete(names.long_pkg_name)
      elseif argv.args.w == 'start' then
        WinSvcWrap.SvcStart(names.long_pkg_name)
      elseif argv.args.w == 'stop' then
        WinSvcWrap.SvcStop(names.long_pkg_name)
      end
      return
    end

    if argv.args['restart-sysv-on-upgrade'] then
      virgo.restart_on_upgrade = true
    end

    local options = {}
    options.configFile = argv.args.c or constants:get('DEFAULT_CONFIG_PATH')
    options.pidFile = argv.args.p
    options.lockFile = argv.args.z

    if argv.args.e then
      local mod = require('./runners/' .. argv.args.e)
      return mod.run(argv.args)
    end

    -- Load Unix Signals
    if los.type() ~= 'win32' then loadUnixSignals() end

    if not argv.args.u then -- skip version output on setup
      logging.logf(logging.INFO, "%s (%s)", names.long_pkg_name, virgo.bundle_version)
      logging.logf(logging.INFO, "  virgo %s", virgo.virgo_version)
      logging.logf(logging.INFO, "  luvi %s", luvi.version)
      logging.logf(logging.INFO, "  libuv %s", uv.version_string())
      logging.logf(logging.INFO, "  %s", opensslVersion)
      logging.logf(logging.INFO, "Using config file: %s", options.configFile)
    end

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
        WinSvcWrap.tryRunAsService(names.long_pkg_name, function()
          agent:start(options)
        end) 
      else
        agent:start(options)
      end 
    end
  end)

  if err then
    logging.errorf("Start Error: %s\n%s", err, debug.traceback())
    process:exit(255)
  end
end

return require('luvit')(function(...)
  local options = {}
  options.version = require('./package').version
  options.pkg_name = names.pkg_name
  options.paths = {}
  if los.type() ~= 'win32' then
    options.paths.persistent_dir = "/var/lib/" .. options.pkg_name
    options.paths.exe_dir = options.paths.persistent_dir .. "/exe"
    options.paths.config_dir = "/etc"
    options.paths.library_dir = "/usr/lib/" .. options.pkg_name
    options.paths.runtime_dir = "/tmp"
  else
    local winpaths = require('virgo/util/win_paths')
    options.paths.persistent_dir = path.join(winpaths.GetKnownFolderPath(winpaths.FOLDERID_ProgramData), names.creator_name)
    options.paths.exe_dir = path.join(options.paths.persistent_dir, "exe")
    options.paths.config_dir = path.join(options.paths.persistent_dir, "config")
    options.paths.library_dir = path.join(winpaths.GetKnownFolderPath(winpaths.FOLDERID_ProgramFiles), names.creator_name)
    options.paths.runtime_dir = options.paths.persistent_dir
  end
  options.paths.current_exe = args[0]
  require('virgo')(options, start)
end)
