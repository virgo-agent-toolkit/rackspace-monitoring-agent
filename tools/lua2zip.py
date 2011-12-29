#!/usr/bin/env python
#
#

import sys
import os
from bundle import generate_bundle_map
from zipfile import ZipFile, ZIP_DEFLATED

modules = {
  'lua_modules/lua-async':
    generate_bundle_map('lua-async', 'lua_modules/lua-async'),
  'lib/lua':
    generate_bundle_map(None, 'lib/lua', True),
  'deps/luvit/lib':
    generate_bundle_map(None, 'deps/luvit/lib', True),
  'agents/monitoring/lua':
    generate_bundle_map('monitoring', 'agents/monitoring/lua'),
}

target = sys.argv[1]
sources = sys.argv[2:]

z = ZipFile(target, 'w', ZIP_DEFLATED)
for source in sources:
    if os.path.isdir(source):
      if modules.has_key(source):
        for mod_file in modules[source]:
          z.write(mod_file['os_filename'], mod_file['bundle_filename'])
    else:
      z.write(source, os.path.basename(source))
z.close()
