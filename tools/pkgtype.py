#!/usr/bin/env python
import platform
import subprocess

# Figure out what type of package to build based on platform info
#
# TODO: Windows does MSI?

deb = ['debian', 'ubuntu']
rpm = ['redhat', 'fedora', 'suse', 'opensuse']

dist = platform.dist()[0].lower()


def pkg_type():
    if dist in deb:
        return "deb"

    if dist in rpm:
        return "rpm"

    return None


def pkg_dir():
    dist = platform.dist()

    # Lower case everyting (looking at you Ubuntu)
    dist = tuple([x.lower() for x in dist])

    return "%s-%s" % dist[:2]


def system_info():
    # gather system, machine, and distro info
    machine = platform.machine()
    system = platform.system().lower()
    return (machine, system, pkg_dir())


# git describe return "0.1-143-ga554734"
# git_describe() returns {'release': '143', 'tag': '0.1', 'hash': 'ga554734'}
def git_describe(is_exact=False, split=True):
    options = "--always"

    if is_exact:
        options = "--exact-match"

    describe = "git describe --tags %s" % (options)

    try:
        p = subprocess.Popen(describe,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                shell=True)
    except OSError as e:
        print "ERROR: running: %s" % describe
        print e
        sys.exit(1)

    version, errors = p.communicate()
    if (len(errors)):
        print(errors)
        return None

    version = version.strip()
    if split:
        version = version.split('-')

    return version

if __name__ == "__main__":
    print pkg_type()
