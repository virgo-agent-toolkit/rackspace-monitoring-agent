#!/usr/bin/env python

import sys
import os
from bundle import generate_bundle_map
from zipfile import ZipFile, ZIP_DEFLATED


class VirgoZip(ZipFile):
    lua_table_style = " return {\n%s\n}"

    def __init__(self, *args, **kwargs):
        ZipFile.__init__(self, *args, **kwargs)
        self.mapping = {}

    def add(self, source, target):
        self.write(source, target)
        self.mapping[target] = source

    def to_lua(self):
        """make a lua importable file so we can trace these files
        to where they come from for easier debugging"""
        lua_syntax_list = [('  ["/%s"] = "%s"') % (key, val) for key, val in self.mapping.iteritems()]
        stringified = ",\n".join(lua_syntax_list)
        return self.lua_table_style % (stringified)

    def add_mapping_file(self):
        self.writestr('path_mapping.lua', self.to_lua())


def main():
    lib_lua = os.path.join('lib', 'lua')
    async_lua = os.path.join('modules', 'async')
    bourbon_lua = os.path.join('modules', 'bourbon')
    options_lua = os.path.join('modules', 'options')
    hsm_lua = os.path.join('modules', 'luvit-hsm')
    traceroute_lua = os.path.join('modules', 'traceroute')
    line_emitter_lua = os.path.join('modules', 'line-emitter')
    rackspace_monitoring_client_lua = os.path.join('modules', 'luvit-rackspace-monitoring-client')
    luvit_keystone_client_lua = os.path.join('modules', 'luvit-keystone-client')
    luvit_lua = os.path.join('deps', 'luvit', 'lib', 'luvit')
    monitoring_lua = os.path.join('agents', 'monitoring', 'default')
    collector_lua = os.path.join('agents', 'monitoring', 'collector')
    crash_lua = os.path.join('agents', 'monitoring', 'crash')
    monitoring_tests = os.path.join('agents', 'monitoring', 'tests')
    monitoring_init = os.path.join('agents', 'monitoring', 'init.lua')

    modules = {
        async_lua:
            generate_bundle_map('modules/async', 'modules/async'),
        bourbon_lua:
            generate_bundle_map('modules/bourbon', 'modules/bourbon'),
        options_lua:
            generate_bundle_map('modules/options', 'modules/options'),
        hsm_lua:
            generate_bundle_map('modules/hsm', 'modules/luvit-hsm'),
        traceroute_lua:
            generate_bundle_map('modules/traceroute', 'modules/traceroute'),
        line_emitter_lua:
            generate_bundle_map('modules/line-emitter', 'modules/line-emitter'),
        luvit_keystone_client_lua:
            generate_bundle_map('modules/keystone', 'modules/luvit-keystone-client'),
        rackspace_monitoring_client_lua:
            generate_bundle_map('modules/rackspace-monitoring', 'modules/luvit-rackspace-monitoring-client'),
        lib_lua:
            generate_bundle_map('', 'lib/lua', True),
        luvit_lua:
            generate_bundle_map('', 'deps/luvit/lib/luvit', True),
        monitoring_lua:
            generate_bundle_map('modules/monitoring/default', 'agents/monitoring/default'),
        collector_lua:
            generate_bundle_map('modules/monitoring/collector', 'agents/monitoring/collector'),
        monitoring_tests:
            generate_bundle_map('modules/monitoring/tests', 'agents/monitoring/tests'),
        crash_lua:
            generate_bundle_map('modules/monitoring/crash', 'agents/monitoring/crash'),
        monitoring_init:
            [{'os_filename': "agents/monitoring/init.lua", "bundle_filename": "init.lua"}]
    }

    target = sys.argv[1]
    sources = sys.argv[2:]

    z = VirgoZip(target, 'w', ZIP_DEFLATED)
    for source in sources:
        if source in modules:
            for mod_file in modules[source]:
                z.add(mod_file['os_filename'], mod_file['bundle_filename'])
        else:
            print("ERROR: unmapped file: ", source, target)
            exit(1)

    z.add_mapping_file()
    z.close()

if __name__ == "__main__":
    main()
