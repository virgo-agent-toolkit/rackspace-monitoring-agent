import sys
import os

import optloader

AGENT = None
LUVIT = None
BUNDLE_NAME = None
BUNDLE_DIR = None


def _abs_path(*args):
    return os.path.abspath(os.path.join(*args))

_options = optloader.load_options()

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BUNDLE_DIR = _abs_path(ROOT, _options['variables']['bundle_dir'])
BUNDLE_NAME = _options['variables']['bundle_name']

if BUNDLE_NAME == "/..":
    raise AttributeError('You must call configure with a bundle path.')

if sys.platform == "win32":
    BUILDTYPE = 'Debug' if _options['variables']['virgo_debug'] == 'true' else 'Release'
    BUILD_DIR = _abs_path(ROOT, BUILDTYPE)
    LUVIT = _abs_path(BUILD_DIR, 'luvit.exe')
    AGENT = _abs_path(BUILD_DIR, 'virgo.exe')
else:
    BUILDTYPE = os.environ.get('BUILDTYPE', 'Debug')
    BUILD_DIR = _abs_path(ROOT, 'out', BUILDTYPE)
    LUVIT = _abs_path(BUILD_DIR, 'luvit')
    AGENT = _abs_path(BUILD_DIR, 'virgo')


if __name__ == "__main__":
    os.environ['AGENT_BIN'] = AGENT
    os.environ['LUVIT_BIN'] = LUVIT
