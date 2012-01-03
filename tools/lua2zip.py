#!/usr/bin/env python
#
#

import sys
import os
from bundle import generate_bundle_map
from zipfile import ZipFile, ZIP_DEFLATED

lib_lua = os.path.join('lib', 'lua')
async_lua = os.path.join('lua_modules', 'async')
bourbon_lua = os.path.join('lua_modules', 'bourbon')
options_lua = os.path.join('lua_modules', 'options')
luvit_lua = os.path.join('deps', 'luvit', 'lib')
monitoring_lua = os.path.join('agents', 'monitoring', 'lua')

modules = {
  async_lua:
    generate_bundle_map('modules/async', 'lua_modules/async'),
  bourbon_lua:
    generate_bundle_map('modules/bourbon', 'lua_modules/bourbon'),
  options_lua:
    generate_bundle_map('modules/options', 'lua_modules/options'),
  lib_lua:
    generate_bundle_map('', 'lib/lua', True),
  luvit_lua:
    generate_bundle_map('', 'deps/luvit/lib', True),
  monitoring_lua:
    generate_bundle_map('modules/monitoring', 'agents/monitoring/lua'),
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
