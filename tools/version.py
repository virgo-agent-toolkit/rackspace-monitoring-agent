#!/usr/bin/env python

from optparse import OptionParser
from pkgutils import git_describe

# Generate versions for RPM/dpkg without dashes from git describe
# make release 0 if tag matches exactly
# PKG_VERLIST = $(filter-out dirty,$(subst -, ,$(VERSION))) 0
# PKG_VERSION = $(word 1,$(PKG_VERLIST))
# PKG_RELEASE = $(word 2,$(PKG_VERLIST))


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


def version(sep='-', cwd=None):
    version = git_describe(is_exact=False, split=True, cwd=cwd)
    zeroed = zero_release(version)
    fields = git_describe_fields(zeroed)

    if sep:
        return sep.join(zeroed[:2])

    return fields

if __name__ == "__main__":
    usage = "usage: %prog [field] [--sep=.]"
    parser = OptionParser(usage=usage)
    parser.add_option("-s", "--seperator", dest="seperator", default=None, help="version seperator")
    parser.add_option("-d", "--directory", dest="directory", default=None, help="path to directory ")
    (options, args) = parser.parse_args()

    print version(options.seperator, options.directory)
