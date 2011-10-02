
Import("env")

targets = {}

from os.path import join as pjoin

luasrc = Split("""  lapi.o lcode.o ldebug.o ldo.o ldump.o lfunc.o lgc.o llex.o lmem.o
                    lobject.o lopcodes.o lparser.o lstate.o lstring.o ltable.o ltm.o
                    lundump.o lvm.o lzio.o

                    lauxlib.o lbaselib.o ldblib.o liolib.o lmathlib.o loslib.o ltablib.o
                    lstrlib.o loadlib.o linit.o""")

def transform_lua(e):
  e = e.replace(".o", ".c")
  return pjoin("lua", "src", e)

luasrc = map(transform_lua, luasrc)

lenv = env.Clone()
if env["PLATFORM"] != "win32":
  lenv.Append(CFLAGS=['-DLUA_USE_POPEN'])

targets['static'] = lenv.StaticLibrary('libluastatic', source = luasrc)

headers = Split("""
lua/src/lapi.h		lua/src/ldo.h		lua/src/lmem.h		lua/src/lstring.h	lua/src/lualib.h
lua/src/lauxlib.h	lua/src/lfunc.h		lua/src/lobject.h	lua/src/ltable.h	lua/src/lundump.h
lua/src/lcode.h		lua/src/lgc.h		lua/src/lopcodes.h	lua/src/ltm.h		lua/src/lvm.h
lua/src/lctype.h	lua/src/llex.h		lua/src/lparser.h	lua/src/lua.h		lua/src/lzio.h
lua/src/ldebug.h	lua/src/llimits.h	lua/src/lstate.h	lua/src/luaconf.h
""")

headers = [lenv.File(x) for x in headers]

targets['headers'] = headers

lenv = env.Clone()
lenv.PrependUnique(LIBS=[targets['static']])
if env["PLATFORM"] != "win32" and env["PLATFORM"] != "freebsd":
  lenv.Append(LIBS=['dl', 'pthread'])
targets['luac'] = lenv.Program('luac', source = ['lua/src/luac.c'])[0]
targets['luacmd'] = lenv.Program('luacmd', source = ['lua/src/lua.c'])[0]

Return("targets")
