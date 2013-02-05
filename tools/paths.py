import sys
import os

agent = None
luvit = None

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
build_dir = os.path.join(root, 'out')

BUILDTYPE = os.environ.get('BUILDTYPE', 'Debug')

if sys.platform != "win32":
    output_path = os.path.join(root, 'out', BUILDTYPE)
else:
    output_path = os.path.join(root, BUILDTYPE)

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
