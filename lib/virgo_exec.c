/*
 *  Copyright 2012 Rackspace
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#include "virgo.h"
#include "virgo__types.h"
#include "virgo_error.h"
#include "virgo_paths.h"
#include "virgo_exec.h"

#ifndef _WIN32
#include <unistd.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>

static char**
copy_args(virgo_t *v, const char *bundle_path) {
  int i, index = 1;
  char **args;

  args = malloc((v->argc + 10) * sizeof(char*));

  for(i=1; i<v->argc; i++) {
    if (strcmp(v->argv[i], "-z") == 0) {
      i++;
      continue;
    }
    args[index++] = strdup(v->argv[i]);
  }

  args[index++] = strdup("-z");
  args[index++] = strdup(bundle_path);
  args[index++] = strdup("-n");
  args[index++] = NULL;

  return args;
}

extern char **environ;

static virgo_error_t*
virgo__exec(virgo_t *v, char *exe_path, const char *bundle_path) {
  char **args = copy_args(v, bundle_path);
  int rc;

  args[0] = exe_path;
  rc = execve(exe_path, args, environ);
  if (rc < 0) { /* on success, does not execute */
    return virgo_error_createf(VIRGO_ENOFILE, "execve failed errno=%i", errno);
  }

  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__exec_upgrade(virgo_t *v, virgo__exec_upgrade_cb status) {
  virgo_error_t* err;
  char exe_path[VIRGO_PATH_MAX];
  char bundle_path[VIRGO_PATH_MAX];

  err = virgo__paths_get(v, VIRGO_PATH_EXE, exe_path, sizeof(exe_path));
  if (err) {
    return err;
  }

  err = virgo__paths_get(v, VIRGO_PATH_BUNDLE, bundle_path, sizeof(bundle_path));
  if (err) {
    return err;
  }

  if (status) {
    status(v, "Attempting upgrade to:");
    status(v, "    exe: %s", exe_path);
    status(v, "    bundle: %s", bundle_path);
  }

  return virgo__exec(v, exe_path, bundle_path);
}
