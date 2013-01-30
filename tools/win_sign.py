#!/usr/bin/env python

import os
import sys
import subprocess
from optloader import load_options

# Command set to create and sign with a test software certificate created from a test CA
# "C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\bin\makecert.exe" -r -pe -n "CN=Rackspace Test CA" -a sha256 -cy authority -sky signature -sv testca.pvk testca.cer
# "C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\bin\makecert.exe" -pe -n "CN=Rackspace Test Software Signing Cert" -a sha256 -cy end -sky signature -ic testca.cer -iv testca.pvk -sv testss.pvk testss.cer
# "C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\bin\pvk2pfx.exe" -spc testss.cer -pvk testss.pvk -pfx testss.pfx
# "C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\bin\signtool.exe" sign /d monitoring-agent.exe /v /f testss.pfx Debug/monitoring-agent.exe
#
# Test CA Cert Import
# certutil -user -addstore Root testca.cer

options = load_options()

build = 'Debug' if options['variables']['virgo_debug'] == 'true' else 'Release'
signtool = "C:\\Program Files (x86)\\Microsoft SDKs\\Windows\\v7.0A\\bin\\signtool.exe"
pfx = options['variables']['RACKSPACE_CODESIGNING_KEYFILE']

result = -1

if len(sys.argv) != 2 or not (sys.argv[1] == 'exe' or sys.argv[1] == 'pkg'):
    print "Usage: win_sign.py [exe, pkg]"
    sys.exit(result)

files_to_sign = []

if sys.argv[1] == 'exe':
    files_to_sign = [
        "monitoring-agent.exe",
    ]
if sys.argv[1] == 'pkg':
    files_to_sign = [
        "rackspace-monitoring-agent.msi",
    ]

if os.path.exists(pfx):
    for file in files_to_sign:
        command = "\"%s\" sign /d \"%s\" /v /f \"%s\" \"%s\"" % (signtool, file, pfx, build + "\\" + file)
        result = subprocess.call(command, shell=True)
        if result != 0:
            print "FAILED(%d) CMD : %s" % (result, command)
            break
else:
    print "No PFX found, looking for: %s" % pfx

sys.exit(result)
