#!/usr/bin/env python

import os
import sys
import glob
import getopt

BASEDIR_NAME = 'modules'

def output_file_list(module_name, path):
  for f in os.listdir(path):
    if f.endswith('.lua'):
      print(path + '/' + f)

def generate_bundle_map(module_name, path, is_base=False):
  t = []
  for os_filename in glob.glob(os.path.join(path, '*.lua')):
    if is_base:
      bundle_filename = os.path.basename(os_filename)
    else:
      bundle_filename = BASEDIR_NAME + '/' + module_name + '/' + os.path.basename(os_filename)

    t.append({
      'os_filename': os_filename,
      'bundle_filename': bundle_filename
    })
  return t

try:
  opts, args = getopt.getopt(sys.argv[1:], 'lb', [])
except:
  sys.exit(2)


if __name__ == '__main__':
  module_path = args[0]
  module_name = os.path.basename(module_path)

  for o, a in opts:
    if o == '-l':
      for path in args:
        output_file_list(module_name, path)
    elif o == '-b':
      for path in args:
        print(generate_bundle_map(module_name, path))

