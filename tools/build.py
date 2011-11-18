#!/usr/bin/env python

import os
import sys

# TODO: release/debug

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if sys.platform != "win32":
  os.system("make -C %s" % root)
else:
  os.system("devenv.exe /build Debug virgo.sln /project monitoring-agent.vcproj")

