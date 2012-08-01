# -*- coding: utf-8 -*-
import sys
import re
import json
import urllib
import urllib2
import time
import datetime
import os
import csv

import subprocess as sub

from optparse import OptionParser

CODESPEED_URL = ''

PROJECT = 'virgo'
BRANCH = 'master'
ENVIRONMENT = 'virgo buildbot'
BUILDER_NAME = 'virgo-ubuntu10.04_x86_64'

SLEEP_SECONDS = 60 * 60

COMMAND = '%s ' + \
          '--separator=, -N -t ' + \
          'virgo-memory --no-align -r -S --flush-output %s %s'

def get_revision(options):
    version_run = "%s --version" % options.executable
    try:
        p = sub.Popen(version_run.split(), stdout=sub.PIPE, stderr=sub.PIPE)
    except OSError as e:
        print "ERROR: running: %s" % version_run
        sys.exit(1)
    REVISION, errors = p.communicate()
    if (len(errors)):
        print(errors)

    return REVISION

def send_to_codespeed(url, data):
    response = 'None'

    try:
        f = urllib2.urlopen(url + 'result/add/json/', urllib.urlencode(data))
    except urllib2.HTTPError, error:
        print error.read()
        return

    response = f.read()
    f.close()
    print 'Server (%s) response: %s\n' % (url, response)


def main(options):
    payload = {'json': []}
    props = {}
    benchmark = 'virgo peak memory usage'
    syrupy = os.path.join('.', os.path.dirname(sys.argv[0]), 'syrupy.py')
    command = COMMAND % (syrupy, options.executable, options.options)
    revision = get_revision(options)

    try:
        p = sub.Popen(command.split(), stdout=sub.PIPE, stderr=sub.PIPE)
    except OSError as e:
        print "ERROR: running: %s" % command
        return

    time.sleep(float(options.sleep))

    try:
        p.kill()
    except OSError as e:
        print e
        print "ERROR: died early: %s" % command
        return

    output, errors = p.communicate()

    # ['PID', 'DATE', 'TIME', 'ELAPSED', 'CPU', 'MEM', 'RSS', 'VSIZE']
    csv_reader = csv.DictReader(output.split('\n'))

    max_row = None
    for row in csv_reader:
        if max_row == None or max_row['RSS'] < row['RSS']:
            max_row = row

    date = max_row['DATE'] + ' ' + max_row['TIME']

    entry = {
        'commitid': revision,
        'project': PROJECT,
        'branch': BRANCH,
        'executable': options.executable,
        'benchmark': benchmark,
        'environment': options.environment,
        'result_value': float(max_row['RSS']),
        'revision_date': date,
        'result_date': date
    }
    payload['json'].append(entry)

    print(payload)

    if len(payload['json']) > 0:
        payload['json'] = json.dumps(payload['json'])
        send_to_codespeed(options.url, payload)


if __name__ == '__main__':
    usage = 'usage: %prog'
    parser = OptionParser(usage=usage)
    parser.add_option('--url', dest='url',
                      help='Codespeed instance url')
    parser.add_option('--builder', dest='builder', default=BUILDER_NAME,
                      help='Name of the builder')
    parser.add_option('--executable', dest='executable', default='rackspace-monitoring-agent',
                      help='Executable name (e.g. rackspace-monitoring-agent)')
    parser.add_option('--options', dest='options', default='',
                      help='Options to pass to the executable')
    parser.add_option('--sleep', dest='sleep', default=SLEEP_SECONDS,
                      help='sleep in seconds')
    parser.add_option('--environment', dest='environment', default=ENVIRONMENT,
                      help='Environment name')

    (options, args) = parser.parse_args()
    main(options)
