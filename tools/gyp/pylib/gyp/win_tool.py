#!/usr/bin/env python

# Copyright (c) 2012 Google Inc. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Utility functions for Windows builds.

These functions are executed via gyp-win-tool when using the ninja generator.
"""

import os
import shutil
import subprocess
import sys


def main(args):
  executor = WinTool()
  exit_code = executor.Dispatch(args)
  if exit_code is not None:
    sys.exit(exit_code)


class WinTool(object):
  """This class performs all the Windows tooling steps. The methods can either
  be executed directly, or dispatched from an argument list."""

  def Dispatch(self, args):
    """Dispatches a string command to a method."""
    if len(args) < 1:
      raise Exception("Not enough arguments")

    method = "Exec%s" % self._CommandifyName(args[0])
    return getattr(self, method)(*args[1:])

  def _CommandifyName(self, name_string):
    """Transforms a tool name like recursive-mirror to RecursiveMirror."""
    return name_string.title().replace('-', '')

  def ExecStamp(self, path):
    """Simple stamp command."""
    open(path, 'w').close()

  def ExecRecursiveMirror(self, source, dest):
    """Emulation of rm -rf out && cp -af in out."""
    if os.path.exists(dest):
      if os.path.isdir(dest):
        shutil.rmtree(dest)
      else:
        os.unlink(dest)
    if os.path.isdir(source):
      shutil.copytree(source, dest)
    else:
      shutil.copy2(source, dest)

  def ExecLinkWrapper(self, *args):
    """Filter diagnostic output from link that looks like:
    '   Creating library ui.dll.lib and object ui.dll.exp'
    This happens when there are exports from the dll or exe.
    """
    popen = subprocess.Popen(
        args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out, _ = popen.communicate()
    for line in out.splitlines():
      if not line.startswith('   Creating library '):
        print line
    return popen.returncode

  def ExecMidlWrapper(self, outdir, tlb, h, dlldata, iid, proxy, idl, *flags):
    """Filter noisy filenames output from MIDL compile step that isn't
    quietable via command line flags.
    """
    args = ['midl', '/nologo'] + list(flags) + [
        '/out', outdir,
        '/tlb', tlb,
        '/h', h,
        '/dlldata', dlldata,
        '/iid', iid,
        '/proxy', proxy,
        idl]
    popen = subprocess.Popen(
        args, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out, _ = popen.communicate()
    # Filter junk out of stdout, and write filtered versions. Output we want
    # to filter is pairs of lines that look like this:
    # Processing C:\Program Files (x86)\Microsoft SDKs\...\include\objidl.idl
    # objidl.idl
    lines = out.splitlines()
    prefix = 'Processing '
    processing = set(os.path.basename(x) for x in lines if x.startswith(prefix))
    for line in lines:
      if not line.startswith(prefix) and line not in processing:
        print line
    return popen.returncode

  def ExecRcWrapper(self, *args):
    """Filter logo banner from invocations of rc.exe. Older versions of RC
    don't support the /nologo flag."""
    popen = subprocess.Popen(
        args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out, _ = popen.communicate()
    for line in out.splitlines():
      if (not line.startswith('Microsoft (R) Windows (R) Resource Compiler') and
          not line.startswith('Copyright (C) Microsoft Corporation') and
          line):
        print line
    return popen.returncode

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
