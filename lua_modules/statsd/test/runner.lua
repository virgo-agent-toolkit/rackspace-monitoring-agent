local bourbon = require('bourbon')
local async = require('async')
local fmt = require('string').format

local TESTS_TO_RUN = {
  './process_metrics_test'
}

local failed = 0

if process.env['TEST_FILES'] then
  TESTS_TO_RUN = split(process.env['TEST_FILES'])
end

local function runit(modname, callback)
  local status, mod = pcall(require, modname)
  if status ~= true then
    process.stdout:write(fmt('Error loading test module [%s]: %s\n\n', modname, tostring(mod)))
    callback(mod)
    return
  end
  process.stdout:write(fmt('Executing test module [%s]\n\n', modname))
  bourbon.run(nil, mod, function(err, stats)
    process.stdout:write('\n')

    if stats then
      failed = failed + stats.failed
    end

    callback(err)
  end)
end

function run()
  -- set the exitCode to error in case we trigger some
  -- bug that causes us to exit the loop early
  process.exitCode = 1
  async.forEachSeries(TESTS_TO_RUN, runit, function(err)
    if err then
      p(err)
      debugm.traceback(err)
      remove_tmp(function()
        process.exit(1)
      end)
    end
    process.exitCode = 0
  end)

end

run()
