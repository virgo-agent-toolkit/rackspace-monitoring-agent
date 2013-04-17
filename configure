#!/usr/bin/env python
"""
From <https://github.com/joyent/node/blob/master/configure-gyp>
"""

import optparse
import os
import json
import sys
import ast
import glob
import shutil
import string
from datetime import datetime

from tools import pkgutils
from tools import version

root_dir = os.path.dirname(__file__)

# parse our options
parser = optparse.OptionParser()

parser.add_option("--debug",
    action="store_true",
    dest="debug",
    help="Build debug build")

parser.add_option("--prefix",
    action="store",
    dest="prefix",
    help="Select the install prefix (defaults to /usr/local)")

parser.add_option("--ninja",
    action="store_true",
    dest="ninja_build",
    help="Generate files for the ninja build system")

parser.add_option("--target_arch",
    action="store",
    dest="target_arch",
    help="Select the target architecture (defaults to detected host_arch)")

parser.add_option("--host_arch",
    action="store",
    dest="host_arch",
    help="Select the architecture of the build host (defaults to autodetect)")

parser.add_option("--bundle",
    action="store",
    dest="bundle",
    help="The path to the directory on disk containing lua files to be bundled.")

(options, args) = parser.parse_args()


CHANGE_LOG = """$PKG_NAME ($VERSION) $RELEASE; urgency=$URGENCY

$CHANGES
 -- $MAINTAINER  $TIMESTAMP
"""

CHANGE = """  * $CHANGE\n"""


def debian_changelog(changes, **kwargs):
    CHANGE_LOG_TEMPLATE = string.Template(CHANGE_LOG)

    def _render(changeset):
        version = changeset['version'].strip()
        date = changeset['date'].strip()
        try:
            int(date[-5:])
        except ValueError:
            offset = "-0000"
        else:
            offset = date[-5:]
            date = date[:-5].strip()

        try:
            time = datetime.strptime(date, "%Y-%m-%d %H:%M:%S")
        except ValueError:
            timestamp = date
        else:
            timestamp = time.strftime("%a, %d %b %Y %H:%M:%S") + " " + offset

        rendered_changes = ""
        for change in changeset['changes']:
            rendered_changes += string.Template(CHANGE).safe_substitute(CHANGE=change, **kwargs)
        RELEASE = changeset.get('RELEASE', 'unstable')
        URGENCY = changeset.get('URGENCY', 'low')
        return CHANGE_LOG_TEMPLATE.safe_substitute(CHANGES=rendered_changes,
            VERSION=version, TIMESTAMP=timestamp, RELEASE=RELEASE,
            URGENCY=URGENCY, **kwargs)

    return '\n'.join([_render(c) for c in changes])


def configure_pkg(platform, pkg_vars):
    """slurps up variables from various sources and renders package files
    eg the debian changelog."""
    mapping = pkg_vars.copy()
    for k, v in platform['variables'].items():
        mapping[k] = v
    mapping['TARNAME'] = "%s-%s" % (mapping['PKG_NAME'], mapping['VERSION_FULL'])

    out_dir = os.path.join('pkg', 'out')
    try:
        os.mkdir(out_dir)
    except OSError as e:
        if e.errno != 17:
            raise

    def render(_in, _out):
        template = open(_in, 'rb').read()
        rendered = string.Template(template).safe_substitute(mapping)
        open(_out, 'wb').write(rendered)

    name = mapping['PKG_NAME']

    if mapping['PKG_TYPE'] == 'deb':
        root = os.path.join('pkg', 'debian')
        for f in os.listdir(root):
            render(os.path.join(root, f), os.path.join(out_dir, f))
        log = debian_changelog(mapping['CHANGELOG'], **mapping)

        open(os.path.join(out_dir, 'changelog'), 'wb').\
            write(log.encode('utf8'))

    elif mapping['PKG_TYPE'] == 'rpm':
        render('pkg/rpm/spec.in', 'out/%s.spec' % name)
        render('pkg/systemd/agent.service', 'out/%s.service' % name)
        render('pkg/sysv-redhat/agent', 'out/sysv-%s' % name)
    mapping['WARNING'] = '# autogened by gyp, do not edit by hand'
    if sys.platform != "win32":
        render(os.path.join('pkg', 'include.mk.in'), os.path.join('include.mk'))


def pkg_config(pkg):
    cmd = os.popen('pkg-config --libs %s' % pkg, 'r')
    libs = cmd.readline().strip()
    ret = cmd.close()
    if (ret):
        return None

    cmd = os.popen('pkg-config --cflags %s' % pkg, 'r')
    cflags = cmd.readline().strip()
    ret = cmd.close()
    if (ret):
        return None

    return (libs, cflags)


def uname(switch):
    f = os.popen('uname %s' % switch)
    s = f.read().strip()
    f.close()
    return s


def host_arch():
    """Host architecture. One of arm, ia32 or x64."""

    if sys.platform == "win32":
        return 'ia32'

    if sys.platform == "darwin":
        return 'ia32'

    arch = uname('-p')

    if arch == 'unknown':
        arch = uname('-m')

    return {
        'arm': 'arm',
        'x86': 'ia32',
        'i386': 'ia32',
        'i486': 'ia32',
        'i586': 'ia32',
        'i686': 'ia32',
        'x86_64': 'x64',
        'amd64': 'x64',
    }.get(arch, arch)


def target_arch():
    return host_arch()


def find_toolset(toolsets, toolset_name, variables):
    # find both tools or consider them missing
    for toolset in toolsets:
        found_tools = True
        for tool in toolset.keys():
            if not os.path.exists(toolset[tool]):
                found_tools = False
                break
        if found_tools:
            print "Found", toolset_name, "Toolset"
            # update the paths and force them back into quotes
            for tool in toolset.keys():
                variables[tool] = '"' + toolset[tool] + '"'
            break


def configure_virgo_platform(bundle_dir, platform_vars):
    print('Bundling from %s' % (bundle_dir))

    variables = {}
    variables['BUNDLE_DIR'] = bundle_dir
    variables['BUNDLE_NAME'] = os.path.basename(bundle_dir)
    variables['VIRGO_HEAD_SHA'] = pkgutils.git_head()
    versions = version.version(sep=None)
    variables['PKG_TYPE'] = pkgutils.pkg_type() or ""
    variables['VERSION_FULL'] = versions['tag']
    variables['VERSION_MAJOR'] = versions['major']
    variables['VERSION_MINOR'] = versions['minor']
    variables['VERSION_RELEASE'] = versions['release']
    variables['VERSION_PATCH'] = versions['patch']
    variables['BUNDLE_VERSION'] = version.version(cwd=bundle_dir)

    for k, v in platform_vars.items():
        if k != "CHANGELOG":
            variables[k] = v

    return {'variables': variables}


def configure_virgo():
    # TODO add gdb

    gypi = {
        'variables': {},
        'target_defaults': {
            'include_dirs': [],
            'libraries': [],
            'defines': [],
            'cflags': [],
        }
    }

    variables = gypi['variables']
    variables['virgo_debug'] = 'true' if options.debug else 'false'
    variables['virgo_prefix'] = options.prefix if options.prefix else ''
    variables['luvit_prefix'] = options.prefix if options.prefix else ''
    variables['host_arch'] = options.host_arch if options.host_arch else host_arch()
    variables['target_arch'] = options.target_arch if options.target_arch else target_arch()
    if sys.platform != "win32":
        variables['OPENSSL'] = 'openssl'
    else:
        supported_wix_toolsets = [
            {
                'LIGHT_EXE': "C:\\Program Files (x86)\\WiX Toolset v3.7\\bin\\light.exe",
                'CANDLE_EXE': "C:\\Program Files (x86)\\WiX Toolset v3.7\\bin\\candle.exe",
            },
            {
                'LIGHT_EXE': "C:\\Program Files (x86)\\Windows Installer XML v3.6\\bin\\light.exe",
                'CANDLE_EXE': "C:\\Program Files (x86)\\Windows Installer XML v3.6\\bin\\candle.exe",
            },
        ]
        # set defaults to missing
        variables['LIGHT_EXE'] = '"tools\\win_tool_missing.bat" "light.exe"'
        variables['CANDLE_EXE'] = '"tools\\win_tool_missing.bat" "candle.exe"'

        find_toolset(supported_wix_toolsets, "WiX", variables)

        # Specifiy the location of the codesigning cert as a signtool.exe param
        windows_key_loc = "windows_key_location\\rackspace.pfx"
        if (os.path.exists(windows_key_loc)):
            variables['RACKSPACE_CODESIGNING_KEYFILE'] = windows_key_loc
        else:
            variables['RACKSPACE_CODESIGNING_KEYFILE'] = "pkg\\monitoring\\windows\\testss.pfx"
        supported_openssl_toolsets = [
            {
                'OPENSSL': "C:\\Program Files (x86)\\Git\\bin\\openssl.exe",
            },
        ]
        # set defaults to missing
        variables['OPENSSL'] = '"tools\\win_tool_missing.bat" "openssl.exe"'

        find_toolset(supported_openssl_toolsets, "OpenSSL", variables)
    return gypi


def write_gypi(gypi, file_name):
    file_path = os.path.join(root_dir, file_name)
    f = open(file_path, 'w+')
    f.write("# Do not edit. Generated by the configure script.\n")
    json.dump(gypi, f, indent=2, skipkeys=True)
    f.write("\n")
    f.close()


def render_openssl_symlinks(src, dest):
    src = os.path.abspath(src)
    dest = os.path.abspath(dest)
    for x in glob.glob(os.path.join(src, '*.h')):
        with open(x) as f:
            d = f.read().strip()
            srcf = os.path.abspath(os.path.join(src, d))
            destf = os.path.join(dest, os.path.basename(srcf))
            # use copy2, so we preserve mtimes, reducing rebuilds
            shutil.copy2(srcf, destf)


def main():
    print 'Creating GYP include files (.gypi)'
    out_dir = os.path.join('out')
    try:
        os.mkdir(out_dir)
    except OSError as e:
        if e.errno != 17:
            raise

    options_gypi = configure_virgo()
    write_gypi(options_gypi, 'options.gypi')

    # are we being built inside a package (ie, these options should be burned in)
    # TODO: what if a package calls make clean (ie, we won't regenerate out/include.mk because this file exists)
    if os.path.exists(os.path.join(root_dir, 'no_gen_platform_gypi')):
        platform = ast.literal_eval(open('platform.gypi').read())
        bundle_dir = platform['variables']['BUNDLE_DIR']
        virgo_json = os.path.join(bundle_dir, 'virgo.json')
        pkg_vars = ast.literal_eval(open(virgo_json, 'rb').read())
    else:
        if not options.bundle:
            options.bundle = "example"
            print('\nWarning: no bundle path was specified.  The example bundle will be used.\n')
        bundle_dir = os.path.relpath(options.bundle, '.')
        virgo_json = os.path.join(bundle_dir, 'virgo.json')
        pkg_vars = ast.literal_eval(open(virgo_json, 'rb').read())
        platform = configure_virgo_platform(bundle_dir, pkg_vars)
        write_gypi(platform, 'platform.gypi')
    configure_pkg(platform, pkg_vars)

    if os.path.isdir(os.path.join('.', '.git')):
        print "Updating git submodules...."
        os.system(' '.join(['git', 'submodule', 'update', '--init', '--recursive']))

    print "Generating build system with GYP..."

    rv = None
    if sys.platform == "win32":
        os.environ['GYP_MSVS_VERSION'] = '2010'
        render_openssl_symlinks('deps/luvit/deps/openssl/openssl/include/openssl',
            'deps/luvit/deps/openssl/openssl-configs/realized/openssl')
        rv = os.system("python tools\gyp_virgo -f msvs -G msvs_version=2010")
    else:
        cmd = "tools/gyp_virgo"
        if options.ninja_build:
            cmd += " -f ninja"
        rv = os.system(cmd)

    if rv != 0:
        sys.exit(rv)
    print ""
    print "Done!"
    print ""
    if sys.platform == "win32":
        print "Now run `python tools/build.py build` to build!"
    else:
        print "Now run `make` to build!"
    print ""

if __name__ == "__main__":
    main()
