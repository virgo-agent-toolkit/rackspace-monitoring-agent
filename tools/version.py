#!/usr/bin/env python

import sys

def version(args):
    if len(args) == 2:
        return "%s-%s" % (args[0], args[1])
    elif len(args) == 1:
        return "%s" % (args[0])
    else:
        return None

if __name__ == "__main__":
    ver = version(sys.argv[1:])
    if ver == None:
        sys.exit(1)
    print ver
