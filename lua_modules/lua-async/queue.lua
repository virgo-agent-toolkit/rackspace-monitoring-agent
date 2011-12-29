local Queue = {}

function Queue.new()
  return {count = 0, first = 0, last = -1}
end

function Queue.length(list)
  return list.count
end

function Queue.pushleft (list, value)
  local first = list.first - 1
  list.first = first
  list.count = list.count + 1
  list[first] = value
end

function Queue.pushright (list, value)
  local last = list.last + 1
  list.count = list.count + 1
  list.last = last
  list[last] = value
end

function Queue.popleft (list)
  local first = list.first
  if first > list.last then error("list is empty") end
  local value = list[first]
  list[first] = nil        -- to allow garbage collection
  list.first = first + 1
  list.count = list.count - 1
  return value
end

function Queue.popright (list)
  local last = list.last
  if list.first > last then error("list is empty") end
  local value = list[last]
  list[last] = nil         -- to allow garbage collection
  list.last = last - 1
  list.count = list.count - 1
  return value
end

return Queue
