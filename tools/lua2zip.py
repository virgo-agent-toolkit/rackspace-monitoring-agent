#!/usr/bin/env python
#
#

import sys
import os
from zipfile import ZipFile, ZIP_DEFLATED

target = sys.argv[1]
sources = sys.argv[2:]
root = os.path.commonprefix(sources)

z = ZipFile(target, 'w', ZIP_DEFLATED)
for source in sources:
    z.write(source, source[len(root):])
z.close()
