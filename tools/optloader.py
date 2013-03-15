import os
import json
import re

root_dir = os.path.dirname(__file__)

# Regular expression for comments
comment_re = re.compile('^#(.+)$')


def load_options(options="options.gypi"):
    options_filename = os.path.join(root_dir, '..', options)

    opts = {}
    f = open(options_filename, 'rb')
    content = ''
    for line in f.readlines():
        #TODO: this is dumb.  Maybe just write json or something?
        content += line.split("#")[0]
    opts = json.loads(content)
    f.close()

    return opts
