
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

lenv = env.Clone()
lenv.PrependUnique(LIBS=[targets['static']])
if env["PLATFORM"] != "win32" and env["PLATFORM"] != "freebsd":
  lenv.Append(LIBS=['dl', 'pthread'])
targets['luac'] = lenv.Program('luac', source = ['lua/src/luac.c'])[0]
targets['luacmd'] = lenv.Program('luacmd', source = ['lua/src/lua.c'])[0]

Return("targets")
