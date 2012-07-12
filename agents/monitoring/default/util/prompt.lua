local trim = require('./misc').trim

--[[
Ask a question and provide the reponse within the callback.

params -

- question (string) - The question for the user.
- callback (function)(err, response) - The response.
]]--
function ask(question, callback)
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

local exports = {}
exports.ask = ask
return exports
