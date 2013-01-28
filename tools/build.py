#!/usr/bin/env python

import os
import subprocess
import sys
from optloader import load_options

sys.path.insert(0, './')
import paths

options = {}

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
    if sys.platform != "win32":
        agent_tests = os.path.join(paths.root, 'out', paths.BUILDTYPE, 'monitoring-test.zip')
    else:
        agent_tests = os.path.join(paths.root, paths.BUILDTYPE, 'monitoring-test.zip')

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

commands = {
    'crash': crash,
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
