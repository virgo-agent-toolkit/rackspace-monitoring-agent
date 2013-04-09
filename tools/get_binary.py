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
    build_dir = pkgutils.package_builder_dir()
    binary_name = pkgutils.package_binary()
    binary = os.path.join(build_dir, binary_name)

    dest = os.path.join(dest, '%s-monitoring-agent-%s' % (pkgutils.pkg_dir(),
      full_version))
    shutil.move(binary, dest)

    if pkgutils.pkg_type() != 'windows':
        shutil.move(binary + ".sig", dest + ".sig")

if __name__ == "__main__":
    main()
