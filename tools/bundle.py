#!/usr/bin/env python

import os
import sys
import getopt


def file_list(path):
    files = []

    if os.path.isfile(path):
        return [path]

    for f in os.listdir(path):
        new_dir = path + '/' + f
        if os.path.isdir(new_dir) and not os.path.islink(new_dir):
            files.extend(file_list(new_dir))
        else:
            if f.endswith('.lua'):
                files.append(path + '/' + f)
    return files


def generate_bundle_map(module_name, path, is_base=False):
    t = []
    for os_filename in file_list(path):
        bundle_filename = (os_filename.replace(path, '')[1:])
        if is_base:
            bundle_filename = 'modules/' + bundle_filename
        else:
            bundle_filename = module_name + '/' + bundle_filename
        t.append({'os_filename': os_filename, 'bundle_filename': bundle_filename})
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
                print('\n'.join(file_list(path)))
        elif o == '-b':
            for path in args:
                print(generate_bundle_map(module_name, path))
