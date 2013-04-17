import os
import ast

root_dir = os.path.dirname(__file__)


def load_options(options):
    options_filename = os.path.join(root_dir, '..', options)
    with open(options_filename, 'rb') as fd:
        gypi = fd.read()

    return ast.literal_eval(gypi)
