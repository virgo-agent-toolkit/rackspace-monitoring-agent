#!/usr/bin/env luvit

local table = require 'table'
local Timer = require 'timer'
local async = require "./init.lua"
local bourbon = require './bourbon.lua'

local exports = {}

exports['test_forEach'] = function(test, asserts)
  local args = {}
  async.forEach({1,3,2}, function(x, callback)
    Timer.set_timeout(x*25, function()
      table.insert(args, x)
      callback()
    end)
  end, function(err)
    asserts.array_equals(args, {1,2,3})
    test.done()
  end)
end

exports['test_forEachEmptyArray'] = function(test, asserts)
  local args = {}
  async.forEach({}, function(x, callback)
    asserts.ok(false, 'iterator should not be called')
    callback()
  end, function(err)
    asserts.ok(true, "should be called")
    test.done()
  end)
end

exports['test_forEachError'] = function(test, asserts)
  local args = {}
  async.forEach({1,2,3}, function(x, callback)
    table.insert(args, x)
    callback({"error"})
  end, function(err)
    asserts.ok(err ~= nil)
    asserts.ok(#args == 1)
    asserts.ok(args[1] == 1)
    test.done()
  end)
end

exports['test_forEachSeries'] = function(test, asserts)
  local args = {}
  async.forEachSeries({1,3,2}, function(x, callback)
    Timer.set_timeout(x*23, function()
      table.insert(args, x)
      callback()
    end)
  end, function(err)
    asserts.array_equals(args, {1,3,2})
    test.done()
  end)
end

exports['test_forEachSeriesEmptyArray'] = function(test, asserts)
  local args = {}
  async.forEachSeries({}, function(x, callback)
    asserts.ok(false, 'iterator should not be called')
    callback()
  end, function(err)
    asserts.ok(true, "should be called")
    test.done()
  end)
end

exports['test_forEachSeriesError'] = function(test, asserts)
  local args = {}
  async.forEachSeries({1,2,3}, function(x, callback)
    table.insert(args, x)
    callback({"error"})
  end, function(err)
    asserts.ok(err ~= nil)
    asserts.ok(#args == 1)
    asserts.ok(args[1] == 1)
    test.done()
  end)
end

exports['test_forEachLimit'] = function(test, asserts)
  local args = {}
  local arr = {1,2,3,4,5,6,7,8,9}
  async.forEachLimit(arr, 2, function(x, callback)
    Timer.set_timeout(x*5, function()
      table.insert(args, x)
      callback()
    end)
  end, function(err)
    asserts.array_equals(arr, args)
    test.done()
  end)
end

exports['test_forEachLimitEmptyArray'] = function(test, asserts)
  async.forEachLimit({}, 2, function(x, callback)
    asserts.ok(false, 'iterator should not be called')
  end, function(err)
    asserts.ok(true, 'should be called')
    test.done()
  end)
end

exports['test_forEachLimitExceedsSize'] = function(test, asserts)
  local args = {}
  local arr = {0,1,2,3,4,5,6,7,8,9}
  async.forEachLimit(arr, 20, function(x, callback)
    Timer.set_timeout(x*5, function()
      table.insert(args, x)
      callback()
    end)
  end, function(err)
    asserts.array_equals(args, arr)
    test.done()
  end)
end

exports['test_forEachLimitEqualSize'] = function(test, asserts)
  local args = {}
  local arr = {0,1,2,3,4,5,6,7,8,9}
  async.forEachLimit(arr, 10, function(x, callback)
    Timer.set_timeout(x*5, function()
      table.insert(args, x)
      callback()
    end)
  end, function(err)
    asserts.array_equals(args, arr)
    test.done()
  end)
end

exports['test_forEachLimitZeroSize'] = function(test, asserts)
  local args = {}
  local arr = {0,1,2,3,4,5}
  async.forEachLimit(arr, 0, function(x, callback)
    asserts.ok(false, 'iterator should not be called')
    callback()
  end, function(err)
    asserts.ok(true, 'callback should be called')
    test.done()
  end)
end

exports['test_forEachLimitError'] = function(test, asserts)
  local args = {}
  local arr = {0,1,2,3,4,5,6,7,8,9}
  async.forEachLimit(arr, 3, function(x,callback)
    table.insert(args, x)
    if x == 2 then
      callback({"error"})
    end
  end, function(err)
    asserts.ok(err)
    asserts.array_equals(args, {0,1,2})
    test.done()
  end)
end

exports['test_series'] = function(test, asserts)
  local call_order = {}
  async.series({
    function(callback)
      Timer.set_timeout(25, function()
        table.insert(call_order, 1)
        callback(nil, 1)
      end)
    end,
    function(callback)
      Timer.set_timeout(50, function()
        table.insert(call_order, 2)
        callback(nil, 2)
      end)
    end,
    function(callback)
      Timer.set_timeout(15, function()
        table.insert(call_order, 3)
        callback(nil, {3, 3})
      end)
    end
  }, function(err, results)
    asserts.equals(err, nil)
    asserts.equals(results[1], 1)
    asserts.equals(results[2], 2)
    asserts.array_equals(results[3], {3, 3})
    asserts.array_equals(call_order, {1,2,3})
    test.done()
  end)
end

exports['test_seriesEmptyArray'] = function(test, asserts)
  async.series({}, function(err, results)
    asserts.equals(err, nil)
    asserts.array_equals(results, {})
    test.done()
  end)
end

exports['test_seriesError'] = function(test, asserts)
  async.series({
    function(callback)
      callback('error')
    end,
    function(callback)
      asserts.ok(false, 'should not be called')
      callback()
    end
  }, function(err, results)
    asserts.equals(err, 'error')
    asserts.array_equals(results, {})
    test.done()
  end)
end

exports['test_seriesNoCallback'] = function(test, asserts)
  async.series({
    function(callback) callback() end,
    function(callback) callback() ; test.done() end
  })
end

exports['test_seriesObject'] = function(test, asserts)
  local call_order = {}
  local ops = {
    one = function(callback)
      Timer.set_timeout(25, function()
        table.insert(call_order, 1)
        callback(nil, 1)
      end)
    end,
    two = function(callback)
      Timer.set_timeout(50, function()
        table.insert(call_order, 2)
        callback(nil, 2)
      end)
    end,
    three = function(callback)
      Timer.set_timeout(15, function()
        table.insert(call_order, 3)
        callback(nil, 3)
      end)
    end
  }
  async.series(ops, function(err, results)
    asserts.array_equals(call_order, {2,1,3})
    asserts.array_equals(results, {three = 3, one = 1, two = 2})
    test.done()
  end)
end

exports['test_iterator'] = function(test, asserts)
  local call_order = {}
  local iterator = async.iterator({
    function()
      table.insert(call_order, 1)
    end,
    function(arg1)
      asserts.equals(arg1, 'arg1')
      table.insert(call_order, 2)
    end,
    function(arg1, arg2)
      asserts.equals(arg1, 'arg1')
      asserts.equals(arg2, 'arg2')
      table.insert(call_order, 3)
    end
  })
  iterator.run()
  asserts.array_equals(call_order, {1})
  local iterator2 = iterator.run()
  asserts.array_equals(call_order, {1, 1})
  local iterator3 = iterator2.run('arg1')
  asserts.array_equals(call_order, {1, 1, 2})
  local iterator4 = iterator3.run('arg1', 'arg2')
  asserts.array_equals(call_order, {1, 1, 2, 3})
  asserts.equals(iterator4, nil)
  test.done()
end

exports['test_waterfall'] = function(test, asserts)
  local call_order = {}
  async.waterfall({
    function(callback)
      table.insert(call_order, 'fn1')
      Timer.set_timeout(0, function()
        callback(nil, 'one', 'two')
      end)
    end,
    function(arg1, arg2, callback)
      table.insert(call_order, 'fn2')
      asserts.equals(arg1, 'one')
      asserts.equals(arg2, 'two')
      Timer.set_timeout(25, function()
        callback(nil, arg1, arg2, 'three')
      end)
    end,
    function(arg1, arg2, arg3, callback)
      table.insert(call_order, 'fn3')
      asserts.equals(arg1, 'one')
      asserts.equals(arg2, 'two')
      asserts.equals(arg3, 'three')
      callback(nil, 'four')
    end,
    function(arg4, callback)
      table.insert(call_order, 'fn4')
      asserts.array_equals(call_order, {'fn1', 'fn2', 'fn3', 'fn4'})
      callback(nil, 'test')
    end
  }, function(err)
    test.done()
  end)
end

exports['test_waterfallEmptyArray'] = function(test, asserts)
  async.waterfall({}, function(err)
    test.done()
  end)
end

exports['test_waterfallNoCallback'] = function(test, asserts)
  async.waterfall({
    function(callback)
      callback()
    end,
    function(callback)
      callback()
      test.done()
    end
  })
end

exports['test_waterfallAsync'] = function(test, asserts)
  local call_order = {}
  async.waterfall({
    function(callback)
      table.insert(call_order, 1)
      callback()
      table.insert(call_order, 2)
    end,
    function(callback)
      table.insert(call_order, 3)
      callback()
    end,
    function()
      asserts.array_equals(call_order, {1,2,3})
      test.done()
    end
  })
end

exports['test_waterfallError'] = function(test, asserts)
  async.waterfall({
    function(callback)
      callback('error')
    end,
    function(callback)
      asserts.ok(false, 'Function should not be called')
      callback()
    end
  }, function(err)
    asserts.equals(err, 'error')
    test.done()
  end)
end

exports['test_waterfallMultipleCallbacks'] = function(test, asserts)
  local call_order = {}
  local arr
  arr = {
    function(callback)
      table.insert(call_order, 1)
      -- Call the callback twice, should call function 2 twice
      callback(null, 'one', 'two')
      callback(null, 'one', 'two')
    end,
    function(arg1, arg2, callback)
      table.insert(call_order, 2)
      callback(nil, arg1, arg2, 'three')
    end,
    function(arg1, arg2, arg3, callback)
      table.insert(call_order, 3)
      callback(nil, 'four')
    end,
    function(arg4)
      table.insert(call_order, 4)
      arr[4] = function()
        table.insert(call_order, 4)
        asserts.array_equals(call_order, {1,2,2,3,3,4,4});
        test.done()
      end
    end
  }
  async.waterfall(arr)
end

exports['test_parallel'] = function(test, asserts)
  local call_order = {}
  async.parallel({
    function(callback)
      Timer.set_timeout(50, function()
        table.insert(call_order, 1)
        callback(nil, 1)
      end)
    end,
    function(callback)
      Timer.set_timeout(100, function()
        table.insert(call_order, 2)
        callback(nil, 2)
      end)
    end,
    function(callback)
      Timer.set_timeout(25, function()
        table.insert(call_order, 3)
        callback(nil, 3, 3)
      end)
    end
  },
  function(err, results)
    asserts.array_equals(call_order, {3,1,2})
    asserts.array_equals(results[1], {1})
    asserts.array_equals(results[2], {2})
    asserts.array_equals(results[3], {3,3})
    test.done()
  end)
end

exports['test_parallelEmpty'] = function(test, asserts)
  async.parallel({}, function(err, results)
    asserts.equals(err, nil)
    asserts.array_equals(results, {})
    test.done()
  end)
end

exports['test_parallelError'] = function(test, asserts)
  async.parallel({
    function(callback)
      callback('error', 1)
    end,
    function(callback)
      callback('error2', 2)
    end
  }, function(err, results)
    asserts.equals(err, 'error')
    test.done()
  end)
end

exports['test_parallelNoCallback'] = function(test, asserts)
  async.parallel({
    function(callback) callback() end,
    function(callback) callback() ; test.done() end
  })
end

exports['test_parallelObject'] = function(test, asserts)
  local call_order = {}
  local ops = {}
  ops.one = function(callback)
    Timer.set_timeout(25, function()
      table.insert(call_order, 1)
      callback(nil, 1)
    end)
  end
  ops.two = function(callback)
    Timer.set_timeout(50, function()
      table.insert(call_order, 2)
      callback(nil, 2)
    end)
  end
  ops.three = function(callback)
    Timer.set_timeout(15, function()
      table.insert(call_order, 3)
      callback(nil, 3)
    end)
  end
  async.parallel(ops, function(err, results)
    asserts.array_equals(call_order, {3,1,2})
    asserts.array_equals(results.three, {3})
    asserts.array_equals(results.two, {2})
    asserts.array_equals(results.one, {1})
    test.done()
  end)
end

exports['test_queue'] = function(test, asserts)
  local call_order = {}
  local delays = {40, 20, 60, 20}
  local delay_index = 1
  local q = async.queue(function(task, callback)
    Timer.set_timeout(delays[delay_index], function()
      table.insert(call_order, 'process '..task);
      callback('error', 'arg');
    end)
    delay_index = delay_index + 1
  end, 2)

  q.push(1, function(err, arg)
    asserts.equals(err, 'error')
    asserts.equals(arg, 'arg')
    asserts.equals(q.length(), 1)
    table.insert(call_order, 'callback '.. 1)
  end)
  q.push(2, function(err, arg)
    asserts.equals(err, 'error')
    asserts.equals(arg, 'arg')
    asserts.equals(q.length(), 2)
    table.insert(call_order, 'callback '.. 2)
  end)
  q.push(3, function(err, arg)
    asserts.equals(err, 'error')
    asserts.equals(arg, 'arg')
    asserts.equals(q.length(), 0)
    table.insert(call_order, 'callback '.. 3)
  end)
  q.push(4, function(err, arg)
    asserts.equals(err, 'error')
    asserts.equals(arg, 'arg')
    asserts.equals(q.length(), 0)
    table.insert(call_order, 'callback '.. 4)
  end)

  asserts.equals(q.length(), 4)
  asserts.equals(q.concurrency, 2)

  Timer.set_timeout(200, function()
    asserts.array_equals(call_order, {
      "process 2",
      "callback 2",
      "process 1",
      "callback 1",
      "process 4",
      "callback 4",
      "process 3",
      "callback 3"
    })
    asserts.equals(q.length(), 0)
    asserts.equals(q.concurrency, 2)
    test.done()
  end)
end

exports['test_queueChangeConcurrency'] = function(test, asserts)
  local call_order = {}
  local delays = {40, 20, 60, 20}
  local delay_index = 1
  local q = async.queue(function(task, callback)
    Timer.set_timeout(delays[delay_index], function()
      table.insert(call_order, 'process '..task);
      callback('error', 'arg');
    end)
    delay_index = delay_index + 1
  end, 2)

  q.push(1, function(err, arg)
    asserts.equals(err, 'error')
    asserts.equals(arg, 'arg')
    asserts.equals(q.length(), 3)
    table.insert(call_order, 'callback '.. 1)
  end)
  q.push(2, function(err, arg)
    asserts.equals(err, 'error')
    asserts.equals(arg, 'arg')
    asserts.equals(q.length(), 2)
    table.insert(call_order, 'callback '.. 2)
  end)
  q.push(3, function(err, arg)
    asserts.equals(err, 'error')
    asserts.equals(arg, 'arg')
    asserts.equals(q.length(), 1)
    table.insert(call_order, 'callback '.. 3)
  end)
  q.push(4, function(err, arg)
    asserts.equals(err, 'error')
    asserts.equals(arg, 'arg')
    asserts.equals(q.length(), 0)
    table.insert(call_order, 'callback '.. 4)
  end)

  asserts.equals(q.length(), 4)
  asserts.equals(q.concurrency, 2)
  q.concurrency = 1

  Timer.set_timeout(250, function()
    asserts.array_equals(call_order, {
      "process 1",
      "callback 1",
      "process 2",
      "callback 2",
      "process 3",
      "callback 3",
      "process 4",
      "callback 4"
    })
    asserts.equals(q.concurrency, 1)
    asserts.equals(q.length(), 0)
    test.done()
  end)
end

bourbon.run(exports)
