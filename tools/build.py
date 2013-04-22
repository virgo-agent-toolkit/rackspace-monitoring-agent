#!/usr/bin/env python

import os
import subprocess
import sys
import optloader
import paths


def _call(cmd, **kwargs):
    print(cmd)
    sys.exit(subprocess.call(cmd, shell=True, **kwargs))


def _build(prod=False):
    env_str = ''
    if prod:
        env_str = 'PRODUCTION=1'
    if sys.platform.find('freebsd') == 0:
        cmd = '%s gmake -C %s' % (env_str, paths.root)
    elif sys.platform != "win32":
        cmd = '%s make -C %s' % (env_str, paths.root)
    else:
        if prod:
            env_str = 'Production'
        cmd = 'tools\win_build.bat %s %s' % (paths.BUILDTYPE, env_str)
    _call(cmd)


def build():
    _build()


def build_prod():
    _build(True)


def pkg():
    if sys.platform.find('freebsd') == 0:
        cmd = 'BUILDTYPE=%s gmake -C %s pkg' % (paths.BUILDTYPE, paths.ROOT)
    elif sys.platform != "win32":
        cmd = 'BUILDTYPE=%s make -C %s pkg' % (paths.BUILDTYPE, paths.ROOT)
    else:
        cmd = 'tools\win_pkg.bat %s' % paths.BUILDTYPE

    print cmd
    sys.exit(subprocess.call(cmd, shell=True))


def sig_gen(signingkey, filename, sigfilename):
    options = optloader.load_options('options.gypi')
    cmd = '%s dgst -sha256 -sign %s %s > %s' % (
        options['variables']['OPENSSL'], signingkey, filename, sigfilename)
    print cmd
    sys.exit(subprocess.call(cmd, shell=True))


def exe_sign():
    if sys.platform == "win32":
        cmd = 'tools\win_sign.py exe'
    else:
        print "Executable Signing is only supported on Win32"
        sys.exit(1)

    _call(cmd)


def pkg_sign():
    if sys.platform.find('freebsd') == 0:
        cmd = 'BUILDTYPE=%s gmake -C %s pkg-sign' % (paths.BUILDTYPE, paths.ROOT)
    elif sys.platform != "win32":
        cmd = 'BUILDTYPE=%s make -C %s pkg-sign' % (paths.BUILDTYPE, paths.ROOT)
    else:
        cmd = 'tools\win_sign.py pkg'
    _call(cmd)


def test(stdout=None, entry="tests", flags=None):
    bundle = os.path.join(paths.BUILD_DIR, "%s-bundle.zip" % (paths.BUNDLE_NAME))

    cmd = '%s -o -d --zip %s -e %s' % (paths.AGENT, bundle, entry)

    if flags:
        cmd += " ".join(flags)

    _call(cmd, stdout=stdout)


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
    'build_prod': build_prod,
    'sig-gen': sig_gen,
    'pkg': pkg,
    'exe-sign': exe_sign,
    'pkg-sign': pkg_sign,
    'test': test,
    'test_pipe': test_pipe,
    'test_file': test_file,
}


def main():
    if len(sys.argv) < 2:
        raise ValueError('Usage: build.py [%s]' % ', '.join(commands.keys()))

    command = commands.get(sys.argv[1], None)

    if command is None:
        raise ValueError('Invalid command: %s' % sys.argv[1])

    if sys.platform.find('freebsd') == 0:
        os.environ['CC'] = 'gcc48'
        os.environ['CXX'] = 'g++48'

    print('Running %s' % sys.argv[1])

    command(*sys.argv[2:])

if __name__ == "__main__":
    main()
