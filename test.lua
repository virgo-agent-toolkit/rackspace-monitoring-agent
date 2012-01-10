#!/usr/bin/env luvit

local bourbon = require('./lua_modules/bourbon')

bourbon.run(require('./tests/agent-protocol/test'))
