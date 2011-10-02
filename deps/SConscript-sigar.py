
import sys
from os.path import join as pjoin

Import("env")

targets = {}

### Building libsigar.a
lenv = env.Clone()
sigarsrc = Split("""sigar.c
  sigar_cache.c
  sigar_fileinfo.c
  sigar_format.c
  sigar_getline.c
  sigar_ptql.c
  sigar_signal.c
  sigar_util.c
""")

lenv.Append(CPPPATH=['#deps/sigar/include'])
osname = None
#  aix darwin freebsd hpux linux solaris win32
if env["PLATFORM"] == "win32":
  osname = "win32"
  lenv.Append(CFLAGS=['-DWIN32_LEAN_AND_MEAN', '-D_BIND_TO_CURRENT_MFC_VERSION=1'
                      '-D_BIND_TO_CURRENT_CRT_VERSION=1', '-D_CRT_SECURE_NO_WARNINGS'])
elif env["PLATFORM"] == "darwin":
  osname = "darwin"
  lenv.AppendUnique(CFLAGS=['-DDARWIN'])
  lenv.Append(CPPPATH=['/Developer/Headers/FlatCarbon/'])
elif env["PLATFORM"] == "freebsd":
  osname = "darwin"
elif env["PLATFORM"] == "linux2":
  osname = "linux"
elif env["PLATFORM"] == "posix": # opensuse is posix
  osname = "linux"
else:
  print "Unkonwn platform %s port me in deps/SConscript-sigar" % env["PLATFORM"]
  sys.exit(-1)

lenv.Append(CPPPATH=['#deps/sigar/src/os/'+ osname])

def transform_sigar(e):
  return pjoin("sigar", "src", e)

sigarsrc = map(transform_sigar, sigarsrc)
sigarsrc.extend(lenv.Glob(pjoin(pjoin("sigar", "src","os", osname)+ "/*.c")))
sigarsrc.extend(lenv.Glob(pjoin(pjoin("sigar", "src","os", osname)+ "/*.cpp")))
subst = {'@SCM_REVISION@': 'c439f0e2b3edeb1bcad0802027ff17b1ce61230b',
         '@PACKAGE_STRING@': 'cksigar',
         '@build@': 'release',
         '@build_os@': env['PLATFORM'],
         '@build_cpu@': env['VIRGO_PLATFORM'],
         '@PACKAGE_VERSION@': '1.7.0',
         '@VERSION_MAJOR@': '1',
         '@VERSION_MINOR@': '7',
         '@VERSION_MAINT@': '0',
         '@VERSION_BUILD@': '0'}
sigarver = env.SubstFile('sigar/src/sigar_version_autoconf.c.in', SUBST_DICT = subst)
sigarsrc.append(sigarver)
targets['static'] = lenv.StaticLibrary('sigarstatic', source=sigarsrc)
targets['cpppaths'] = ['#deps/sigar/include']
Return("targets")
