#!/usr/bin/env python

import os
import subprocess
import sys

# TODO: release/debug

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
build_dir = os.path.join(root, 'out')

def build():
  if sys.platform != "win32":
      cmd = 'make -C %s' % build_dir
  else:
      cmd = 'tools\win_build.bat'

  print cmd
  sys.exit(subprocess.call(cmd, shell=True))

def test():
  agent = os.path.join(root, 'out', 'Debug', 'monitoring-agent')
  cmd = '%s --zip out/Debug/monitoring-test.zip -e tests -c docs/sample.state' % agent
  print cmd
  rc = subprocess.call(cmd, shell=True)
  sys.exit(rc)

commands = {
  'build': build,
  'test': test,
}

def usage():
  print('Usage: build.py [%s]' % ', '.join(commands.keys()))
  sys.exit(1)

if len(sys.argv) != 2:
  usage()

ins = sys.argv[1]
if not commands.has_key(ins):
  print('Invalid command: %s' % ins)
  sys.exit(1)

print('Running %s' % ins)
cmd = commands.get(ins)
cmd()

