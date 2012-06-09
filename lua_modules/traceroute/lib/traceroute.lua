local Emitter = require('core').Emitter
local Error = require('core').Error
local table = require('table')
local childprocess = require('childprocess')

local split = require('./utils').split

local exports = {}

-- TODO: Move LineEmitter and split into utils or smth

local LineEmitter = Emitter:extend()

function LineEmitter:initialize(initialBuffer)
  self._buffer = initialBuffer or ''
end

function LineEmitter:feed(chunk)
  local line

  self._buffer = self._buffer .. chunk

  line = self:_popLine()
  while line do
    self:emit('line', line)
    line = self:_popLine()
  end
end

function LineEmitter:_popLine()
  local line = false
  local index = self._buffer:find('\n')

  if index then
    line = self._buffer:sub(0, index - 1)
    self._buffer = self._buffer:sub(index + 1)
  end

  return line
end

local Traceroute = Emitter:extend()

function Traceroute:initialize(target, options)
  options = options and options or {}
  self._target = target
  self._options = options
  self._packetLen = options['packetLen'] and options['packetLen'] or 60
  self._maxTtl = options['maxTtl'] and options['maxTtl'] or 30

  if target:find(':') then
    self._addressType = 'ipv6'
  else
    self._addressType = 'ipv4'
  end
end

-- Return an EventEmitter instance which emits 'hop' events for every hop
function Traceroute:traceroute()
  process.nextTick(function()
    local emitter = self:_run(self._target)

    emitter:on('end', function()
      self:emit('end')
    end)

    emitter:on('hop', function(hop)
      self:emit('hop', hop)
    end)

    emitter:on('error', function(err)
      self:emit('error', err)
    end)
  end)
end

function Traceroute:_spawn(cmd, args)
  local child = childprocess.spawn('traceroute', args)
  return child
end

function Traceroute:_run(target)
  local args = {}

  if self._addressType == 'ipv4' then
    table.insert(args, '-4')
  else
    table.insert(args, '-6')
  end

  table.insert(args, '-n')
  table.insert(args, '-m')
  table.insert(args, self._maxTtl)
  table.insert(args, target)
  table.insert(args, self._packetLen)

  local child = self:_spawn('traceroute', args)
  local lineEmitter = LineEmitter:new()
  local emitter = Emitter:new()
  local stderrBuffer = ''

  lineEmitter:on('line', function(line)
    local hops = self:_parseLine(line)
    local hop

    if not hops then
      return
    end

    for i=1, #hops do
      hop = hops[i]
      emitter:emit('hop', hop)
    end
  end)

  child.stdout:on('data', function(chunk)
    lineEmitter:feed(chunk)
  end)

  child.stderr:on('data', function(chunk)
    stderrBuffer = stderrBuffer .. chunk
  end)

  child:on('exit', function(code)
    local err

    if code == 0 then
      emitter:emit('end')
    else
      err = Error:new('Error: ' .. stderrBuffer)
      emitter:emit('error', err)
    end
  end)

  return emitter
end

function Traceroute:_parseLine(line)
  local result = {}, host, ip, hopNumber, dotCount, lastIndex
  local item = {}
  local hopsStart = 2

  -- Skip first line
  if line:find('traceroute to') then
    return
  end

  -- for now just ignore those
  line = line:gsub('[!XHNP]', '')

  local splitLine = split(line, '[^%s]+')

  hopNumber = tonumber(splitLine[1])

  local util = require('utils')

  i = hopsStart -- hops start at index 2
  while i < #splitLine do
    value = splitLine[i]
    dotCount = #split(value, '[^%.]+')
    nextValue = value[i + 2]

    if (self:_isAddress(value, self._addressType)) or (value == '*' and i == hopsStart) then
      if i > hopsStart then
        -- Insert old item
        table.insert(result, item)
      end

      item = {}
      item['ip'] = value
      item['number'] = hopNumber
      item['rtts'] = {}
    elseif value ~= 'ms' then
      value = tonumber(value)
      table.insert(item['rtts'], value)
    end

    i = i + 1
  end

  table.insert(result, item)

  return result
end

function Traceroute:_isAddress(value, family)
  local dotCount, result

  if family == 'ipv4' then
    dotCount = #split(value, '[^%.]+')
    return dotCount == 4
  else
    return value:find(':')
  end
end

exports.Traceroute = Traceroute
return exports
