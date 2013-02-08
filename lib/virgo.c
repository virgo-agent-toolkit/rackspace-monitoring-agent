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
#include "virgo_paths.h"
#include "virgo_exec.h"
#include "virgo_versions.h"
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#ifndef _WIN32
#include <unistd.h>
#else
#include <io.h>
#endif

static void
handle_error(const char *msg, virgo_error_t *err)
{
  char buf[256];

  snprintf(buf, sizeof(buf), "%s: %s", msg, "[%s:%d] (%d) %s");
  fprintf(stderr, buf, err->file, err->line, err->err, err->msg);
  fputs("\n", stderr);
  fflush(stderr);
  virgo_error_clear(err);
}

static void
show_help()
{
  /* TODO: improve for windows */
  printf("Usage: rackspace-monitoring-agent [options] [--setup] \n"
         "\n"
         "Options:\n"
         "  -v, --version         Print monitoring-agent's version.\n"
         "  -c, --config val      Set configuration file path. Default: /etc/rackspace-monitoring-agent.cfg\n"
         "  -b, --bundle-dir val  Force the bundle directory.\n"
         "  -e val                Enter at module specified.\n"
         "  -o                    Do not attempt upgrade.\n"
         "  -l, --logfile val     Log to specified file path.\n"
#ifndef _WIN32
         "  -p, --pidfile val     Path and filename to pidfile.\n"
#endif
         "  -z, --zip val         Path to Zip Bundle.\n"
         "  --setup               Initial setup wizard.\n"
         "    --username          Rackspace Cloud username for setup.\n"
         "    --apikey            Rackspace Cloud API Key or Password for setup.\n"
         "  -d, --debug           Log at debug level.\n"
         "  -i, --insecure        Use insecure SSL CA cert (for testing/debugging).\n"
         "  -D, --detach          Detach the process and run the agent in the background.\n"
         "  --production          Write debug information to disk when the agent crahes.\n"
         "  --crash               Crash the agent.\n"
         "\n"
         "Documentation can be found at http://monitoring.api.rackspacecloud.com/\n");
  fflush(stdout);

}

static void
show_version(virgo_t *v)
{
  printf("%s\n", VERSION_FULL);
  fflush(stdout);
}

static void
upgrade_status_cb(virgo_t *v, const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  virgo_log_fmtv(v, VIRGO_LOG_INFO, fmt, ap);
  va_end(ap);
}

int main(int argc, char* argv[])
{
  virgo_t *v;
  virgo_error_t *err;
  char path[VIRGO_PATH_MAX];

  err = virgo_create(&v, "./init", argc, argv);

  if (err) {
    handle_error("Error in startup", err);
    return EXIT_FAILURE;
  }

  /* Set Service Name */
  err = virgo_conf_service_name(v, "Rackspace Monitoring Agent");
  if (err) {
    handle_error("Error setting service name", err);
    return EXIT_FAILURE;
  }

  /* Read command-line arguments */
  err = virgo_conf_args(v);
  if (err) {
    handle_error("Error in settings args", err);
    return EXIT_FAILURE;
  }

  /* See if we are upgrading */
  if (virgo_try_upgrade(v)) {
    /* Attempt upgrade. On success this process gets replaced. */
    err = virgo__exec_upgrade(v, upgrade_status_cb);
    if (err) {
      if (err->err == VIRGO_ENOFILE) {
        virgo_log_info(v, "Continuing Startup without Upgrade");
      } else {
        virgo_log_errorf(v, "Exec Error: %s", err->msg);
        virgo_error_clear(err);
      }
    } else {
      /* this code never gets executed because of execve */
      return 0;
    }
  }

  err = virgo__paths_get(v, VIRGO_PATH_CURRENT_EXECUTABLE_PATH, path, sizeof(path));
  if (err) {
    handle_error("Could not find current executable name", err);
    return EXIT_FAILURE;
  }

  virgo_log_infof(v, "Process Executable: %s", path);

  /* Check to see if bundle is valid */
  err = virgo__bundle_is_valid(v);
  if (err) {
    handle_error("Virgo Bundle is invalid", err);
    return EXIT_FAILURE;
  }

  virgo_log_infof(v, "Bundle: %s", virgo_get_load_path(v));

  /* Setup Lua Contexts for Luvit and Libuv runloop */
  err = virgo_init(v);
  if (err) {
    if (err->err == VIRGO_EHELPREQ) {
      show_help();
      virgo_error_clear(err);
      return 0;
    }
    else if (err->err == VIRGO_EVERSIONREQ) {
      show_version(v);
      virgo_error_clear(err);
      return 0;
    }

    handle_error("Error in init", err);
    return EXIT_FAILURE;
  }

  err = virgo_agent_conf_set(v, "version", VERSION_FULL);
  if (err) {
    handle_error("Error setting agent version", err);
    return EXIT_FAILURE;
  }

  /* Enter Luvit and Execute */
  err = virgo_run(v);
  if (err) {
    handle_error("Runtime Error", err);
    return EXIT_FAILURE;
  }

  /* Cleanup */
  virgo_destroy(v);
  return 0;
}
