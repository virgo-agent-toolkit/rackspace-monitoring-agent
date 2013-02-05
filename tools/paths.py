import sys
import os
from optloader import load_options

agent = None
luvit = None

options = load_options()

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
build_dir = os.path.join(root, 'out')

BUILDTYPE = os.environ.get('BUILDTYPE', 'Debug')
if sys.platform == "win32":
    BUILDTYPE = 'Debug' if options['variables']['virgo_debug'] == 'true' else 'Release'

if sys.platform != "win32":
    agent = os.path.join(root, 'out', BUILDTYPE, 'monitoring-agent')
else:
    agent = os.path.join(root, BUILDTYPE, 'monitoring-agent.exe')

if sys.platform != "win32":
    luvit = os.path.join(root, 'out', BUILDTYPE, 'luvit')
else:
    luvit = os.path.join(root, BUILDTYPE, 'luvit.exe')

if __name__ == "__main__":
    os.environ['AGENT_BIN'] = agent
    os.environ['LUVIT_BIN'] = luvit
