local async = {}

local timer = require 'timer'
local table = require 'table'
local Queue = require './queue.lua'

--[[
-- auto -- todo
--]]

async.forEach = function(arr, iterator, callback)
  if #arr == 0 then
    return callback()
  end
  local completed = 0
  for i=1,#arr do
    local elem = arr[i]
    iterator(elem, function(err)
      if err then
        local cb = callback
        callback = function() end
        return cb(err)
      end
      completed = completed + 1
      if completed == #arr then
        return callback()
      end
    end)
  end
end

async.forEachSeries = function(arr, iterator, callback)
  if #arr == 0 then
    return callback()
  end
  local completed = 0
  local iterate
  iterate = function()
    return iterator(arr[completed + 1], function(err)
      if err then
        local cb = callback
        callback = function() end
        return cb(err)
      end
      completed = completed + 1
      if completed == #arr then
        return callback()
      end
      return iterate()
    end)
  end
  return iterate()
end

async.reduce = function(arr, memo, iterator, callback)
  return async.forEachSeries(arr, function(x, callback)
    return iterator(memo, x, function(err, v)
      memo = v
      return callback(err)
    end)
  end, function(err)
    return callback(err, memo)
  end)
end

async.forEachLimit = function(arr, limit, iterator, callback)
  if #arr == 0 or limit <= 0 then
    return callback()
  end
  local completed = 0
  local started = 0
  local running = 0

  local replenish
  replenish = function()
    if completed == #arr then
      return callback()
    end
    while running < limit and started < #arr do
      started = started + 1
      running = running + 1
      iterator(arr[started], function(err)
        if err then
          local cb = callback
          callback = function() end
          return cb(err)
        end
        completed = completed + 1
        running = running - 1
        if completed == #arr then
          return callback()
        end
        return replenish()
      end)
    end
  end
  return replenish()
end

-- Map
local _forEach = function(arr, iterator)
  for k, v in pairs(arr) do
    iterator(v, k, arr)
  end
end

local _map = function(arr, iterator)
  local results = {}
  _forEach(arr, function(x, i, a)
    return table.insert(results, iterator(x, i, a))
  end)
  return results
end

local doParallel = function(fn)
  return function(arr, iterator, callback)
    return fn(async.forEach, arr, iterator, callback)
  end
end

local doSeries = function(fn)
  return function(arr, iterator, callback)
    return fn(async.forEachSeries, arr, iterator, callback)
  end
end

local _asyncMap = function(eachfn, arr, iterator, callback)
  local results = {}
  arr = _map(arr, function(x, i)
    return {index=i, value=x}
  end)
  return eachfn(arr, function(x, callback)
    return iterator(x.value, function(err, v)
      results[x.index] = v
      return callback(err)
    end)
  end, function(err)
    return callback(err, results)
  end)
end

async.map = doParallel(_asyncMap)
async.mapSeries = doSeries(_asyncMap)

-- Filter
local _filter = function(eachfn, arr, iterator, callback)
  local results = {}
  arr = _map(arr, function(x, i)
   return {index=i, value=x}
  end)
  return eachfn(arr, function(x, callback)
    return iterator(x.value, function(v)
      if v == 1 then
        table.insert(results, 1, x)
      end
      return callback()
    end)
  end, function(err)
    table.sort(results, function(a, b)
      return a.index - b.index
    end)
    return callback(_map(results, function(x)
      return x.value
    end))
  end)
end

async.filter = doParallel(_filter)
async.filterSeries = doSeries(_filter)


-- Reject

local _reject = function(eachfn, arr, iterator, callback)
  local results = {}
  arr = _map(arr, function(x, i)
    return {index=i, value=x}
  end)
  return eachfn(arr, function(x, callback)
    return iterator(x.value, function(v)
      if not v then
        table.insert(results, 1, x)
      end
      return callback()
    end, function(err)
      table.sort(results, function(a, b)
        return a.index - b.index
      end)
      return callback(_map(results, function(x)
        return x.value
      end))
    end)
  end)
end

async.reject = doParallel(_reject)
async.rejectSeries = doSeries(_reject)

--  Detect

local _detect = function(eachfn, arr, iterator, main_callback)
  return eachfn(arr, function(x, callback)
    return iterator(x, function(result)
        if result then
          local cb = main_callback
          main_callback = function() end
          return cb(x)
        end
        return callback()
      end, function(err)
        return main_callback()
    end)
  end)
end

async.detect = doParallel(_detect)
async.detectSeries = doSeries(_detect)

-- Sortby

async.sortBy = function(arr, iterator, callback)
  return async.map(arr, function(x, callback)
    return iterator(x, function(err, criteria)
      if err then
        return callback(err)
      end
      return callback(nil, {value=x, criteria=criteria})
    end)
  end, function (err, results)
    if err then
      return callback(err)
    end
    local fn
    fn = function(left, right)
      local a = left.criteria
      local b = right.criteria
      if a < b then
        return -1
      elseif a > b then
        return 1
      else
        return 0
      end
    end
    table.sort(results, fn)
    return callback(nil, _map(results, function(x)
      return x.value
    end))
  end)
end

-- Some or any

async.some = function(arr, iterator, main_callback)
  return async.forEach(arr, function(x, callback)
    return iterator(x, function(v)
      if v then
        main_callback(true)
        main_callback = function() end
      end
      return callback()
    end)
  end, function(err)
  end)
end

async.any = async.some

-- Every

async.every = function(arr, iterator, main_callback)
  return async.forEach(arr, function(x, callback)
    return iterator(x, function(v)
      if not v then
        main_callback(false)
        main_callback = function() end
      end
      return callback()
    end)
  end, function(err)
    return main_callback(true)
  end)
end

async.all = async.every

-- Concat

-- https://gist.github.com/978161
--   permission pending
-- table.copy( array, ... ) returns a shallow copy of array.
-- A variable number of additional arrays can be passed in as
-- optional arguments. If an array has a hole (a nil entry),
-- copying in a given source array stops at the last consecutive
-- item prior to the hole.
--
-- Note: In Lua, the function table.concat() is equivalent
-- to JavaScript's array.join(). Hence, the following function
-- is called copy().
table.copy = function( t, ... )
  local copyShallow = function( src, dst, dstStart )
    local result = dst or {}
    local resultStart = 0
    if dst and dstStart then
      resultStart = dstStart
    end
    local resultLen = 0
    if "table" == type( src ) then
      resultLen = #src
      for i=1,resultLen do
        local value = src[i]
        if nil ~= value then
          result[i + resultStart] = value
        else
          resultLen = i - 1
          break;
        end
      end
    end
    return result,resultLen
  end

  local result, resultStart = copyShallow( t )

  local srcs = { ... }
  for i=1,#srcs do
    local _,len = copyShallow( srcs[i], result, resultStart )
    resultStart = resultStart + len
  end

  return result
end

local _concat = function(eachfn, arr, fn, callback)
  local r = {}
  return eachfn(arr, function(x, cb)
    return fn(x, function(err, y)
      r = table.copy(y or {})
      return cb(err)
    end)
  end, function(err)
    return callback(err, r)
  end)
end

async.concat = doParallel(_concat)
async.concatSeries = doSeries(_concat)

-- Whilst

async.whilst = function(test, iterator, callback)
  if not test() then
    return callback()
  end

  return iterator(function(err)
    if err then
      return callback(err)
    end
    return async.whilst(test, iterator, callback)
  end)
end

-- Until

async.Until = function(test, iterator, callback)
  if test() then
    return callback()
  end

  return iterator(function(err)
    if err then
      return callback(err)
    end
    return async.Until(test, iterator, callback)
  end)
end

-- Series
async.series = function(tasks, callback)
  callback = callback or function() end
  if tasks[1] then
    return async.mapSeries(tasks, function(fn, callback)
      if fn then
        return fn(function(err, ...)
          return callback(err, unpack({...}))
        end)
      end
    end, callback)
  end

  local _keys = {}
  local results = {}
  for k, v in pairs(tasks) do
    table.insert(_keys, 1, k)
  end
  return async.forEachSeries(_keys, function(k, callback)
    tasks[k](function(err, ...)
      results[k] = {...}
      return callback(err)
    end)
  end, function(err)
    return callback(err, results)
  end)
end

-- Iterator
async.iterator = function(tasks)
  local makeCallback
  makeCallback = function(index)
    local it = {}
    it.Next = function()
      if index < #tasks then
        return makeCallback(index + 1)
      else
        return nil
      end
    end
    it.run = function(...)
      if #tasks > 0 then
        tasks[index](unpack({...}))
      end
      return it.Next()
    end
    return it
  end
  return makeCallback(1)
end

-- Waterfall
async.waterfall = function(tasks, callback)
  local wrapIterator
  if #tasks == 0 then
    return callback()
  end
  callback = callback or function() end
  wrapIterator = function(iterator)
    return function(err, ...)
      if err then
        local cb = callback
        callback = function() end
        return cb(err)
      end

      local args = {...}
      local _next = iterator.Next()
      if _next then
        table.insert(args, wrapIterator(_next))
      else
        table.insert(args, callback)
      end
      return timer.setTimeout(0, function()
        return iterator.run(unpack(args))
      end)
    end
  end
  return wrapIterator(async.iterator(tasks))()
end

-- Parallel
async.parallel = function(tasks, callback)
  callback = callback or function() end
  return async.map(tasks, function(fn, callback)
    if fn then
      return fn(function(err, ...)
        return callback(err, {...})
      end)
    end
  end, callback)
end

-- Queue

async.queue = function(worker, concurrency)
  local workers = 0
  local q = {}
  q.tasks = Queue.new()
  q.concurrency = concurrency
  q.saturated = nil
  q.empty = nil
  q.drain = nil
  q.length = function()
    return Queue.length(q.tasks)
  end
  q.running = function()
    return workers
  end
  q.process = function()
    if workers < q.concurrency and q.length() > 0 then
      local task = Queue.popleft(q.tasks)
      if q.empty and q.length() == 0 then q.empty() end
      workers = workers + 1
      return worker(task.data, function(...)
        workers = workers - 1
        if task.callback then
          task.callback(unpack({...}))
        end
        if q.drain and (q.length() + workers) == 0 then
          q.drain()
        end
        return q.process()
      end)
    end
  end
  q.push = function(data, callback)
    Queue.pushright(q.tasks, { data = data, callback = callback })
    if q.saturated and q.length() == concurrency then
      q.saturated()
    end
    return timer.setTimeout(0, q.process)
  end
  return q
end

return async
