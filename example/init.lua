require('async')
require('bourbon')


local argv = require("options")
  .usage('Usage: ')
  .describe("e", "entry module")
  .argv("e:")

return {
	["run"] = function()

		local entry = argv.args.e
		if entry then
			return require(entry).run(argv.args)
		end

  	print('hello world')
	end
}