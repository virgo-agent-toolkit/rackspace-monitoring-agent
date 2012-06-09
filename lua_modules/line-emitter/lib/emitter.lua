local Emitter = require('core').Emitter

local exports = {}

local LineEmitter = Emitter:extend()

function LineEmitter:initialize(initialBuffer)
  self._buffer = initialBuffer and initialBuffer or ''
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

exports.LineEmitter = LineEmitter
return exports
