
Import("env")

targets = {}

src = Split("""http_parser/http_parser.c""")

lenv = env.Clone()
lenv.Append(CPPPATH=['#deps/http_parser'])

targets['static'] = lenv.StaticLibrary('libhttpparserstatic', source = src)
targets['cpppaths'] = ['#deps/http_parser']

Return("targets")
