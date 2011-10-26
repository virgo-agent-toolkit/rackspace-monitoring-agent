
Import("env")

targets = {}

from os.path import join as pjoin

src = Split("""adler32.c
compress.c
crc32.c
deflate.c
gzclose.c
gzlib.c
gzread.c
gzwrite.c
inflate.c
infback.c
inftrees.c
inffast.c
trees.c
uncompr.c
zutil.c
win32/zlib1.rc
""")

def transform_zlib(e):
  return pjoin("zlib", e)

src = map(transform_zlib, src)

lenv = env.Clone()
if env["PLATFORM"] != "win32":
    lenv.Append(CPPDEFINES=['HAVE_SYS_TYPES_H', 'HAVE_STDINT_H', 'HAVE_STDDEF_H', '_LARGEFILE64_SOURCE=1'])
else:
    #TODO: not sure these are right
    lenv.Append(CPPDEFINES=['_CRT_SECURE_NO_DEPRECATE', '_CRT_NONSTDC_NO_DEPRECATE'])
    
targets['static'] = lenv.StaticLibrary('libzlib', source = src)
targets['cpppaths'] = ['#deps/zlib']

Return("targets")
