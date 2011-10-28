
Import("env")

targets = {}

src = Split("""monitoring/monitoring.c""")
luasrc = Split("""
monitoring/lua/init.lua
""")
lenv = env.Clone()
lenv.Append(LIBS=env['AGENT_LIBS'])

targets['app'] = lenv.Program('monitoring-agent', source = src)
targets['luapack'] = lenv.Zip('monitoring.zip', luasrc)

Return("targets")
