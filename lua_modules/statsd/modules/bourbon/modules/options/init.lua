-- luvit-getopt -- by pancake<nopcode.org> --
local string = require ("string")

local Options = {}
Options.args = {} -- this is tab!

Options._alias = {}
Options._describe = {}
Options._check = nil
Options._usage = nil
Options._demand = nil

function Options.usage (str)
	if #str == 0 then
		Options._usage = nil
	else
		Options._usage = str
	end
	return Options
end

function Options.showUsage (options)
	print (Options._usage)
	if Options._describe then
		print ("Options:")
		local width = 20
		for k, v in pairs (Options._describe) do
			local line = "  -"..k
			for i, j in pairs (Options._alias) do
				if k == i then
					line = line..", --"..j
				end
			end
			if string.find (options, k..":", 1, true) then
				line = line.." [arg]"
			end
			local w = width - #line
			line = line..string.rep (" ", w)
			-- TODO align columns
			line = line .."   "..v
			if Options._demand then
				for i, j in pairs (Options._demand) do
					if k == j then
						line = line.."  *required*"
					end
				end
			end
			print (line)
		end
	end
end

-- getopt, POSIX style command line argument parser
-- param arg contains the command line arguments in a standard table.
-- param options is a string with the letters that expect string values.
-- returns a table where associated keys are true, nil, or a string value.
-- The following example styles are supported
--   -a one  ==> opts["a"]=="one"
--   -bone   ==> opts["b"]=="one"
--   -c      ==> opts["c"]==true
--   --no-c  ==> opts["c"]=false
--   --c=one ==> opts["c"]=="one"
--   -cdaone ==> opts["c"]==true opts["d"]==true opts["a"]=="one"
-- note POSIX demands the parser ends at the first non option
--      this behavior isn't implemented.
function Options.parse (arg, options)
	if Options._demand and #arg == 0 and Options._usage then
		Options.showUsage (options)
		process.exit (1)
	end

	local ind = 0
	local skip = 0
	local tab = Options.args
	tab["_"] = {}
	tab["$0"] = arg[0]

	for k, v in ipairs (arg) do repeat
		if skip>0 then
			skip = skip - 1
			break
		end
		for a, b in pairs (Options._alias) do
			if v == "--"..b then
				v = "-"..a
			end
		end
		if string.sub (v, 1, 2) == "--" then
			local bool
			local boolk
			if string.sub (v, 2,5) == "-no-" then
				bool = false
				boolk = string.sub (v,6)
			else
				bool = true
				boolk = string.sub (v,3)
			end
			local x = string.find (v, "=", 1, true)
			if x then tab[string.sub (v, 3, x-1)] = string.sub (v, x+1)
			else tab[boolk] = bool
			end
		elseif string.sub (v, 1, 1) == "-" then
			local y = 2
			local l = string.len (v)
			local jopt
			while (y <= l) do
				jopt = string.sub (v, y, y)
				local off = string.find (options, jopt, 1, true)
				if off then
					local ch = string.sub (options, off+1, off+1)
					if y < l then
						tab[jopt] = string.sub (v, y+1)
						y = l
					else
						if ch == ":" then
							skip = 1
							tab[jopt] = arg[k + 1]
							if not tab[jopt] then
								print ("Missing argument for "..v)
								process.exit (1)
							end
						else
							tab[jopt] = true
						end
					end
				else
					tab[jopt] = true
				end
				tab[jopt] = tonumber(tab[jopt]) or tab[jopt]
				if(Options._alias[jopt]) then
					tab[Options._alias[jopt]] = tab[jopt]
				end
				y = y + 1
			end
		else
			tab["_"][ind] = v
			ind = ind+1
		end
	until true end
	if Options._demand then
		for k,v in pairs (Options._demand) do
			if not tab[v] then
				print ("Missing required argument -"..v)
				process.exit (1)
			end
		end
	end
	if Options._check and not Options._check (tab) then
		print ("luvit-getopt: check condition failed")
		process.exit (1)
	end
	return Options
end

function Options.argv (opt)
	return Options.parse (process.argv, opt)
end

function Options.demand (dem)
	Options._demand = dem
	return Options
end

function Options.default (k, v)
	if v then
		Options.args[k] = v
	else
		for i, j in pairs (k) do
			Options.args[i] = j
		end
	end
	return Options
end

function Options.alias (k, v)
	if type (k) == "table" then
		for i,j in pairs (k) do
			Options._alias[i] = j
		end
	else
		Options._alias[k] = v
	end
	return Options
end

function Options.check (fn)
	Options._check = fn
	return Options
end

function Options.describe (k,v)
	if type (k) == "table" then
		for i, j in pairs (k) do
			Options._describe[i] = j
		end
	else
		Options._describe[k] = v
	end
	return Options
end

return Options
