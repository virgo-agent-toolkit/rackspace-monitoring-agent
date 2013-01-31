#!/usr/bin/env python

import os
import sys
import shutil

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

    binary = os.path.join(build_dir, 'monitoring-agent')

    dest = os.path.join(dest, '%s-monitoring-agent' % (pkgutils.pkg_dir()))
    shutil.move(binary, dest)
    shutil.move(binary + ".sig", dest + ".sig")

if __name__ == "__main__":
    main()
