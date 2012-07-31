#!/usr/bin/env python
import platform

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

    return Null

def pkg_dir():
    dist = platform.dist()

    # Lower case everyting (looking at you Ubuntu)
    dist = [x.lower() for x in dist]

    return "%s-%s" % dist[:2]

if __name__ == "__main__":
    print pkg_type()
