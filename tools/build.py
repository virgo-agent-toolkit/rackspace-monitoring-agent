#!/usr/bin/env python

import os
import shutil
import subprocess
import sys
import paths
from optloader import load_options

options = {}

DEFAULT_BUNDLE_PREFIX = 'monitoring'
DEFAULT_BUNDLE_NAME = "%s.zip" % DEFAULT_BUNDLE_PREFIX
DEFAULT_SIGNATURE_NAME = "%s.zip.sig" % DEFAULT_BUNDLE_PREFIX
DEFAULT_BUNDLE_PATH = os.path.join(paths.root, '..', 'bundle')


def _get_bundle_filename(filename=DEFAULT_BUNDLE_NAME):
    return os.path.join(paths.output_path, filename)


def _get_signature_filename(filename=DEFAULT_SIGNATURE_NAME):
    return os.path.join(paths.output_path, filename)


def _get_version():
    # capture the current version
    cmd = 'python tools/version.py'
    print cmd
    p = subprocess.Popen(["python", "tools/version.py"], stdout=subprocess.PIPE)
    version, err = p.communicate()
    return version.strip()


def extra_env():
    env = {}
    if sys.platform.find('freebsd') == 0:
        env['CC'] = 'gcc48'
        env['CXX'] = 'g++48'
    return env


def build():
    if sys.platform.find('freebsd') == 0:
        cmd = 'gmake -C %s' % paths.root
    elif sys.platform != "win32":
        cmd = 'make -C %s' % paths.root
    else:
        build = 'Debug' if options['variables']['virgo_debug'] == 'true' else 'Release'
        cmd = 'tools\win_build.bat %s' % build

    print cmd
    sys.exit(subprocess.call(cmd, shell=True))


def pkg():
    if sys.platform.find('freebsd') == 0:
        cmd = 'BUILDTYPE=%s gmake -C %s pkg' % (paths.BUILDTYPE, paths.root)
    elif sys.platform != "win32":
        cmd = 'BUILDTYPE=%s make -C %s pkg' % (paths.BUILDTYPE, paths.root)
    else:
        build = 'Debug' if options['variables']['virgo_debug'] == 'true' else 'Release'
        cmd = 'tools\win_pkg.bat %s' % build

    print cmd
    sys.exit(subprocess.call(cmd, shell=True))


def exe_sign():
    if sys.platform == "win32":
        cmd = 'tools\win_sign.py exe'
    else:
        print "Executable Signing is only supported on Win32"
        sys.exit(1)

    print cmd
    sys.exit(subprocess.call(cmd, shell=True))


def pkg_sign():
    if sys.platform.find('freebsd') == 0:
        cmd = 'BUILDTYPE=%s gmake -C %s pkg-sign' % (paths.BUILDTYPE, paths.root)
    elif sys.platform != "win32":
        cmd = 'BUILDTYPE=%s make -C %s pkg-sign' % (paths.BUILDTYPE, paths.root)
    else:
        cmd = 'tools\win_sign.py pkg'
    print cmd
    sys.exit(subprocess.call(cmd, shell=True))


def test_cmd(additional=""):
    state_config = os.path.join(paths.root, 'contrib')
    monitoring_config = os.path.join(paths.root, 'agents', 'monitoring', 'tests', 'fixtures', 'monitoring-agent-localhost.cfg')

    return '%s -o -d -c %s -s %s %s' % (paths.agent, monitoring_config, state_config, additional)


def test(stdout=None, entry="tests", flags=None):
    agent_tests = _get_bundle_filename('monitoring-test.zip')
    cmd = test_cmd("--zip %s -e %s -o" % (agent_tests, entry))
    if flags:
        for flag in flags:
            cmd += " %s" % (flag)
    print cmd
    rc = 0
    if stdout is None:
        rc = subprocess.call(cmd, shell=True)
    else:
        rc = subprocess.call(cmd, shell=True, stdout=stdout)
    sys.exit(rc)


def test_std():
    test()


def test_pipe():
    test(subprocess.PIPE)


def test_file():
    stdout = open("stdout", "w+")
    test(stdout)


def crash():
    test(None, "crash", flags=["--production"])


def bundle(directory=DEFAULT_BUNDLE_PATH):
    bundle_filename = _get_bundle_filename()
    signature_filename = _get_signature_filename()
    version = _get_version()

    print "Removing %s" % (directory)
    shutil.rmtree(directory, True)
    print "mkdir %s" % (directory)
    os.mkdir(directory)

    # copy bundle
    dest_path = os.path.join(directory, "monitoring-%s.zip" % (version))
    print "Copying %s to %s" % (_get_bundle_filename(), dest_path)
    shutil.copy(_get_bundle_filename(), dest_path)

    # copy signature
    dest_path = os.path.join(directory, "monitoring-%s.zip.sig" % (version))
    print "Copying %s to %s" % (_get_signature_filename(), dest_path)
    shutil.copy(_get_signature_filename(), dest_path)

    # create VERSION file
    version_file_name = os.path.join(directory, 'VERSION')
    print "Creating %s" % (version_file_name)
    version_file = open(version_file_name, "w")
    version_file.write(version)
    version_file.write('\n')
    version_file.close()


commands = {
    'crash': crash,
    'bundle': bundle,
    'build': build,
    'pkg': pkg,
    'exe-sign': exe_sign,
    'pkg-sign': pkg_sign,
    'test': test_std,
    'test_pipe': test_pipe,
    'test_file': test_file,
}


def usage():
    print('Usage: build.py [%s]' % ', '.join(commands.keys()))
    sys.exit(1)

if len(sys.argv) != 2:
    usage()

ins = sys.argv[1]
if not ins in commands:
    print('Invalid command: %s' % ins)
    sys.exit(1)

extra_env = extra_env()

for key in extra_env.keys():
    os.environ[key] = extra_env[key]

options = load_options()

print('Running %s' % ins)
cmd = commands.get(ins)
cmd()
