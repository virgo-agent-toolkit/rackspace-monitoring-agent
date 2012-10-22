local trim = require('./misc').trim
local async = require('async')

--[[
Ask a question and provide the reponse within the callback.

params -

- question (string) - The question for the user.
- callback (function)(err, response) - The response.
]]--
function ask(question, callback)
  local resp = ''

  function try(question, callback)
    local response = ''
    process.stdin:resume()
    process.stdout:write(question .. ' ')
    process.stdin:on('data', function(data)
      response = response .. data
      if response:find('\n') then
        process.stdin:pause()
        process.stdin:removeListener('data')
        callback(nil, trim(response))
      end
    end)
  end

  function test()
    return #resp == 0
  end

  function iter(callback)
    try(question, function(err, data)
      resp = data
      callback(err, data)
    end)
  end

  async.whilst(test, iter, function(err)
    callback(err, resp)
  end)
end

local exports = {}
exports.ask = ask
return exports
