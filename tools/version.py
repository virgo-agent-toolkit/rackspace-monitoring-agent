#!/usr/bin/env python

import subprocess
import sys
from optparse import OptionParser

# Generate versions for RPM/dpkg without dashes from git describe
# make release 0 if tag matches exactly
# PKG_VERLIST = $(filter-out dirty,$(subst -, ,$(VERSION))) 0
# PKG_VERSION = $(word 1,$(PKG_VERLIST))
# PKG_RELEASE = $(word 2,$(PKG_VERLIST))

usage = "usage: %prog [field] [--sep=.]"
parser = OptionParser(usage=usage)
parser.add_option("-s", "--seperator", dest="seperator", default="-",
                          help="version seperator", metavar="SEP")
(options, args) = parser.parse_args()

# git describe return "0.1-143-ga554734"
# git_describe() returns {'release': '143', 'tag': '0.1', 'hash': 'ga554734'}
def git_describe():
    describe = "git describe --tags --always"

    try:
        p = subprocess.Popen(describe.split(),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE)
    except OSError as e:
        print "ERROR: running: %s" % describe
        print e
        sys.exit(1)

    version, errors = p.communicate()
    if (len(errors)):
        print(errors)
        sys.exit(1)

    version = version.strip().split('-')

    return version

# If there is no release then it is zero
def zero_release(version):
    if len(version) == 1:
        version.append("0")
        return version

    return version

def git_describe_fields(version):
    fields = ["tag", "release", "hash", "major", "minor", "patch"]
    version.extend(version[0].split('.'))
    return dict(zip(fields, version))

version = git_describe()
zeroed = zero_release(version)
fields = git_describe_fields(zeroed)

if len(args) == 1:
    print("%s" % fields.get(args[0], ""))
    sys.exit(0)

print(options.seperator.join(zeroed[:2]))
