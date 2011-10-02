
Import("env")

targets = {}

from os.path import join as pjoin

gyp = None

with open(env.File('#deps/uv/uv.gyp').get_abspath()) as fd:
    contents = fd.read()
    gyp = eval(contents, {'__builtins__': None}, None)

uvtarget = [x for x in gyp['targets'] if x['target_name'] == 'uv'][0]

src = uvtarget['sources']

def transform_uv(e):
  return pjoin("uv", e)

src = map(transform_uv, src)

lenv = env.Clone()

lenv.Append(CPPPATH=[pjoin('#deps/uv/', x) for x in uvtarget['include_dirs']])
lenv.Append(CPPDEFINES=uvtarget['defines'])

thisos = {'WINDOWS': 'OS="win"',
          'DARWIN': 'OS=="mac"',
          'LINUX': 'OS=="linux"',
          'SUNOS': 'OS=="solaris"',
          'FREEBSD': 'OS=="freebsd"'}.get(lenv['VIRGO_PLATFORM'])

extralibs = []

def add_vars(env, cvars):
    env.Append(CFLAGS=cvars.get('cflags', []))
    env.Append(CPPPATH=[pjoin('#deps/uv/', x) for x in cvars.get('include_dirs', [])])
    env.Append(CPPDEFINES=[x.replace('"', '\\"') for x in cvars.get('defines', [])])
    src.extend([pjoin('uv', x) for x in cvars.get('sources', [])])
    extralibs.extend(cvars.get('libraries', []))

for cond in uvtarget['conditions']:
    match = cond[0]
    if match == thisos:
        add_vars(lenv, cond[1])
    elif (len(cond) >= 3):
        add_vars(lenv, cond[2])

targets['static'] = lenv.StaticLibrary('libuvstatic', source = src)
targets['libs'] = extralibs
targets['cpppaths'] = ['#deps/uv/include']

Return("targets")
