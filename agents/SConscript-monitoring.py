
Import("env")

targets = {}

src = Split("""monitoring/monitoring.c""")

lenv = env.Clone()
lenv.Append(LIBS=env['AGENT_LIBS'])

targets['app'] = lenv.Program('monitoring-agent', source = src)

Return("targets")
