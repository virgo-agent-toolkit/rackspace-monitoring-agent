#
#  Copyright 2011 Rackspace
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#


import os

def CheckUname(context, args):
  prog = context.env.WhereIs("uname")
  context.Message("Checking %s %s ...." % (prog, args))
  output = context.sconf.confdir.File(os.path.basename(prog)+'.out') 
  node = context.sconf.env.Command(output, prog, [ [ prog, args, ">", "${TARGET}"] ]) 
  ok = context.sconf.BuildNodes(node) 
  if ok: 
    outputStr = output.get_contents().strip()
    context.Result(" "+ outputStr)
    return (1, outputStr)
  else:
    context.Result("error running uname")
    return (0, "")

