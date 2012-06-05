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
  self._target = target
  self._options = options or {}
  self._resolveIps = self._options['resolveIps'] or false
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
  local args = {target}

  if not self._resolveIps then
    table.insert(args, '-n')
  end

  local child = self:_spawn('traceroute', args)
  local lineEmitter = LineEmitter:new()
  local emitter = Emitter:new()
  local stderrBuffer = ''

  lineEmitter:on('line', function(line)
    local hop = self:_parseLine(line)

    if hop then
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
  local result = {}, host, ip, hopsIndex

  -- Skip first line
  if line:find('traceroute to') then
    return
  end

  local split = split(line, '[^%s]+')

  if self._resolveIps then
    hopsIndex = 4
    result['host'] = split[2]
    result['ip'] = split[3]:gsub('%(', ''):gsub('%)', '')
  else
    hopsIndex = 3
    result['ip'] = split[2]:gsub('%(', ''):gsub('%)', '')
  end

  result['rtts'] = {}

  for i=hopsIndex, #split, 1 do
    value = split[i]
    if not value:find('ms') then
      if value == '*' then
        value = nil
      else
        value = tonumber(value)
      end

      table.insert(result['rtts'], value)
    end
  end

  return result
end

exports.Traceroute = Traceroute
return exports
