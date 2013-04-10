#!/usr/bin/env python

import os
import sys
import shutil

from version import full_version
from optparse import OptionParser

import pkgutils


def main():
    usage = "usage: %prog [destination path]"
    parser = OptionParser(usage=usage)
    (options, args) = parser.parse_args()

    if len(args) != 1:
        parser.print_usage()
        sys.exit(1)

    dest = args[0]
    orig_dest = dest
    build_dir = pkgutils.package_builder_dir()
    binary_name = pkgutils.package_binary()
    binary = os.path.join(build_dir, binary_name)

    dest = os.path.join(dest, '%s-monitoring-agent-%s' % (pkgutils.pkg_dir(),
      full_version))
    if pkgutils.pkg_type() == 'windows':
        dest += '.msi'
    print("Moving %s to %s" % (binary, dest))
    shutil.move(binary, dest)

    onlyfiles = [f for f in os.listdir(orig_dest) if os.path.isfile(os.path.join(orig_dest, f))]
    for f in onlyfiles:
        print(f)

    if pkgutils.pkg_type() != 'windows':
        shutil.move(binary + ".sig", dest + ".sig")

if __name__ == "__main__":
    main()
