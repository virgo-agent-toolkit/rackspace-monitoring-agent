local trim = require('./util/misc').trim

--[[
Constructor.

Ask a question and provide the reponse within the callback.

params -

- question (string) - The question for the user.
- callback (function)(err, response) - The response.
]]--
function ask(question, callback)
  local response = ''
  process.stdin:readStart()
  process.stdout:write(question .. ' ')
  process.stdin:once('data', function(data)
    response = response .. data
    if response:find('\n') then
      process.stdin:readStop()
      callback(nil, trim(response))
    end
  end)
end

local exports = {}
exports.ask = ask
return exports
