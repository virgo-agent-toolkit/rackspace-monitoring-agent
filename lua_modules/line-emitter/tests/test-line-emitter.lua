local LineEmitter = require('../lib/emitter').LineEmitter

local exports = {}

exports['test_line_emitter_single_chunk'] = function(test, asserts)
  local count = 0
  local lines = {'test1', 'test2', 'test3', 'test4'}
  local le = LineEmitter:new()

  le:on('line', function(line)
    count = count + 1
    asserts.equals(line, lines[count])

    if count == 4 then
      test.done()
    end
  end)

  le:feed('test1\ntest2\ntest3\ntest4\n')
end

exports['test_line_emitter_multiple_chunks'] = function(test, asserts)
  local count = 0
  local lines = {'test1', 'test2', 'test3', 'test4', 'test5'}
  local le = LineEmitter:new()

  le:on('line', function(line)
    count = count + 1
    asserts.equals(line, lines[count])

    if count == 5 then
      test.done()
    end
  end)

  le:feed('test1\n')
  le:feed('test2\n')
  le:feed('test3\n')
  le:feed('test4\ntest5')
  le:feed('\n')
end

return exports
