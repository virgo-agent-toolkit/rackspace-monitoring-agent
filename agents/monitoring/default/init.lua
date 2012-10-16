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

local MonitoringAgent = require('./monitoring_agent').MonitoringAgent
local Setup = require('./setup').Setup
local constants = require('./util/constants')

local function main(argv)
  argv = argv and argv or {}
  local options = {}

  if argv.s then
    options.stateDirectory = argv.s
  end

  options.configFile = argv.c or constants.DEFAULT_CONFIG_PATH

  if argv.p then
    options.pidFile = argv.p
  end

  if argv.i then
    options.tls = {
      rejectUnauthorized = true,
      ca = require('./certs').caCertsDebug
    }
  end

  local agent = MonitoringAgent:new(options)

  -- setup will exit and not fall through
  if not argv.u then
    return agent:start(options)
  end

  Setup:new(argv, options.configFile, agent):run()


  if argv.u then
    options.configFile = options.configFile or constants.DEFAULT_CONFIG_PATH
    local setup = Setup:new(argv, options.configFile, agent)
    setup:run()
  else
    agent:start(options)
  end
end

return {
  run = main
}
