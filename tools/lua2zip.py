#!/usr/bin/env python
#
#

import sys
import os
from zipfile import ZipFile, ZIP_DEFLATED

target = sys.argv[1]
sources = sys.argv[2:]
# we used to support subdirectories, now every .lua
# file is put into the root of the zip, reconsider this
# someday?
# root = os.path.commonprefix(sources)

z = ZipFile(target, 'w', ZIP_DEFLATED)
for source in sources:
    # z.write(source, source[len(root):])
    z.write(source, os.path.basename(source))
z.close()
