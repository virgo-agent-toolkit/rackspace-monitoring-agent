#!/usr/bin/env python

import os
import subprocess
import sys

# TODO: release/debug

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
build_dir = os.path.join(root, 'out')

def build():
  if sys.platform.find('freebsd') == 0:
      cmd = 'gmake -C %s' % build_dir
  elif sys.platform != "win32":
      cmd = 'make -C %s' % build_dir
  else:
      cmd = 'tools\win_build.bat'

  print cmd
  sys.exit(subprocess.call(cmd, shell=True))

def pkg():
  if sys.platform.find('freebsd') == 0:
      cmd = 'gmake -C %s pkg' % root
  elif sys.platform != "win32":
      cmd = 'make -C %s pkg' % root
  else:
      cmd = 'tools\win_pkg.bat'

  print cmd
  sys.exit(subprocess.call(cmd, shell=True))

def pkg_sign():
  if sys.platform.find('freebsd') == 0:
      cmd = 'gmake -C %s pkg-sign' % root
  elif sys.platform != "win32":
      cmd = 'make -C %s pkg-sign' % root
  else:
      print 'win32 not supported skipping packaging'
      sys.exit(0)

  print cmd
  sys.exit(subprocess.call(cmd, shell=True))

def test_cmd(additional=""):
  if sys.platform != "win32":
    agent = os.path.join(root, 'out', 'Debug', 'monitoring-agent')
  else:
    agent = os.path.join(root, 'Debug', 'monitoring-agent.exe')

  state_config = os.path.join(root, 'contrib')
  monitoring_config = os.path.join(root, 'agents', 'monitoring', 'tests', 'fixtures', 'monitoring-agent-localhost.cfg')

  return '%s -c %s -s %s %s' % (agent, monitoring_config, state_config, additional)

def test(stdout=None, entry="tests"):
  if sys.platform != "win32":
    agent_tests = os.path.join(root, 'out', 'Debug', 'monitoring-test.zip')
  else:
    agent_tests = os.path.join(root, 'Debug', 'monitoring-test.zip')

  cmd = test_cmd("--zip %s -e %s" % (agent_tests, entry))
  print cmd
  rc = 0
  if stdout == None:
    rc = subprocess.call(cmd, shell=True)
  else:
    rc = subprocess.call(cmd, shell=True, stdout=stdout)
  sys.exit(rc)

def test_std():
  test()

def test_pipe():
  test(subprocess.PIPE)

def test_file():
  stdout = open("stdout", "w+")
  test(stdout)

def crash():
  test(None, "crash")

commands = {
  'crash': crash,
  'build': build,
  'pkg': pkg,
  'pkg-sign': pkg_sign,
  'test': test_std,
  'test_pipe': test_pipe,
  'test_file': test_file,
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

