
Import("env")

targets = {}

from os.path import join as pjoin

lenv = env.Clone()

src = Split("""
minizip/unzip.c
minizip/ioapi.c
minizip/zip.c
""")

if env["PLATFORM"] != "win32":
    lenv.Append(CPPDEFINES=['USE_FILE32API'])

lenv.Append(CPPPATH=["#deps/zlib"])

targets['static'] = lenv.StaticLibrary('libminizip', source = src)
targets['cpppaths'] = ['#deps/minizip']

Return("targets")
