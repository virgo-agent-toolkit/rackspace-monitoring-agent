import os
import json
import re

root_dir = os.path.dirname(__file__)

# Regular expression for comments
comment_re = re.compile('^#(.+)$')


def load_options():
    options_filename = os.path.join(root_dir, '..', 'options.gypi')
    print "reading ", options_filename

    opts = {}
    f = open(options_filename, 'rb')
    content = ''
    for line in f.readlines():
        ## Looking for comments to remove
        match = comment_re.search(line)
        if match:
            line = line[:match.start()] + line[match.end():]

        content = content + line

    opts = json.loads(content)
    f.close()

    return opts
