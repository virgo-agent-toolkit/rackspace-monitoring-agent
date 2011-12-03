#!/usr/bin/env python

import os
import subprocess
import sys

# TODO: release/debug

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if sys.platform != "win32":
    cmd = ['make', '-C', root]
else:
    cmd = ['devenv.exe', '/build', 'Debug', 'virgo.sln', '/project', 'monitoring-agent.vcproj']

print ' '.join(cmd)
subprocess.call(cmd, shell=True)

