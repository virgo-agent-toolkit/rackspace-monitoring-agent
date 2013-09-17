#!/usr/bin/env luvit

local opt = require ("options")
	.usage ("Usage: ./test.lua [-hk] [-a arg] [-b arg]")
	.default ("a", "patata")
	.describe ("a", "set an argument to this flag")
	.describe ("b", "set b flag (required by userdefined check)")
	.describe ("k", "kakaka")
	.describe ("h", "showHelp")
	.alias ({["a"]="arg"})
	.demand ({"a", "k"})
	.check (function (opt)
		return opt.b
	end)
	.argv ("ha:b:k")
p (opt)
