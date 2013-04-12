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
#include "virgo_versions.h"

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
#ifndef _WIN32
  args[index++] = strdup(bundle_path);
  args[index++] = strdup("-o");
#else
  {
    char quoted_bundle[MAX_PATH];
    snprintf(quoted_bundle, MAX_PATH, "\"%s\"", bundle_path);
    args[index++] = strdup(quoted_bundle);
  }
  if (v->service_status.dwCurrentState == SERVICE_RUNNING) {
    args[index++] = strdup("--service-upgrade");
  } else {
    args[index++] = strdup("-o");
  }
#endif
  args[index++] = NULL;

  return args;
}

extern char **environ;

static virgo_error_t*
virgo__exec(virgo_t *v, char *exe_path, const char *bundle_path) {
  char **args = copy_args(v, bundle_path);
  int rc;
  int win_sc_started = 0;
  const char* name = "execve";

  args[0] = exe_path;

#ifdef _WIN32
  /* when running windows from the service manager */
  if (v->service_status.dwCurrentState == SERVICE_RUNNING) {
    win_sc_started = 1;
    name = "spawnve";
  }
  /* a child process must stop the service and perform the upgrade */
  if (!win_sc_started) {
    rc = execve(exe_path, args, environ);
  } else {
    rc = spawnve(P_NOWAIT, exe_path, args, environ);
  }
#else
  rc = execve(exe_path, args, environ);
#endif
  if (rc < 0) {
    return virgo_error_createf(VIRGO_ENOFILE, "%s failed errno=%i", name, errno);
  }

  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__exec_upgrade(virgo_t *v, int *perform_upgrade, virgo__exec_upgrade_cb status) {
  virgo_error_t *exe_err, *err;
  char exe_path[VIRGO_PATH_MAX];
  char latest_in_exe_path[VIRGO_PATH_MAX];
  char bundle_path[VIRGO_PATH_MAX];
  char *exe_path_version;

  *perform_upgrade = FALSE;

  /* get the bundle, latest or default */
  err = virgo__paths_get(v, VIRGO_PATH_BUNDLE, bundle_path, sizeof(bundle_path));
  if (err) {
    if (err->err == VIRGO_ENOFILE) {
      virgo_error_clear(err);
      err = VIRGO_SUCCESS;
    }
    return err;
  }

  /* get the latest exe, an upgrade */
  exe_err = virgo__paths_get(v, VIRGO_PATH_EXE_DIR_LATEST, latest_in_exe_path, sizeof(latest_in_exe_path));

  virgo_error_clear(exe_err);

  /* if no latest exe is found, return and we'll keep running this one */
  if (exe_err) {
    return virgo_error_create(VIRGO_ENOFILE, "No exe upgrades available");
  }

  /* get the exe, latest or default */
  err = virgo__paths_get(v, VIRGO_PATH_EXE, exe_path, sizeof(exe_path));
  if (err) {
    if (err->err == VIRGO_ENOFILE) {
      virgo_error_clear(err);
      err = VIRGO_SUCCESS;
    }
    return err;
  }

  /* Double check the upgraded version is greater than the running process */
  exe_path_version = strrchr(exe_path, '-');
  if (exe_path_version) {
    exe_path_version++; /* skip - */
    if (virgo__versions_compare(exe_path_version, VIRGO_VERSION_FULL) <= 0) {
      /* Skip the upgrade if the exe is less-than or equal than the currently
       * running process.
       */
      return VIRGO_SUCCESS;
    }
  }

  /* a bit of info for the user */
  if (status && ! exe_err) {
    status(v, "Attempting upgrade using new file(s):");
    status(v, "    exe: %s", latest_in_exe_path);
  }

  *perform_upgrade = TRUE;

  /* now we definately have an upgrade to run */
#ifdef _WIN32
  if (v->service_status.dwCurrentState == SERVICE_RUNNING) {
    /* we're running as a service so we need to upgrade the exe into its proper place */
    if (status) {
      status(v, "Service Upgrading");
    }

    /* we run a child of the new exe to shut this service down and upgrade this exe file */
    err = virgo__exec(v, exe_path, bundle_path);
    if (!err) {
      /* wait for the child to shut me down*/
      Sleep(INFINITE);
    }
  } else {
    /* we're not a service, behave like unix and execve the new exe */
    err = virgo__exec(v, exe_path, bundle_path);
  }
#else
  /* execve the new exe */
  err = virgo__exec(v, exe_path, bundle_path);
#endif
  return err;
}
