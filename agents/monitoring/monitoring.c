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
  printf("Usage: monitoring-agent [options] [--setup] \n"
         "\n"
         "Options:\n"
         "  -v, --version         print monitoring-agent's version\n"
         "  -c, --config val      Set configuration file path. Default: /etc/rackspace-monitoring-agent.cfg\n"
         "  -b, --bundle-dir val  Force the bundle directory."
         "  -e val                Entry module.\n"
         "  -l, --logfile val     Path and filename of logfile.\n"
#ifndef _WIN32
         "  -p, --pidfile val     Path and filename to pidfile.\n"
#endif
         "  -z, --zip val         Path to Zip Bundle.\n"
         "  --setup               Initial setup wizard.\n"
         "    --username          Rackspace Cloud username for setup.\n"
         "    --apikey            Rackspace Cloud API Key or Password for setup.\n"
         "  -d, --debug           Log at debug level\n"
         "  -i, --insecure        Use insecure SSL CA cert (for testing/debugging).\n"
         "  -D, --detach          Detach the process and run the agent in the background.\n"
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

int main(int argc, char* argv[])
{
  virgo_t *v;
  virgo_error_t *err;
  int fd;

  err = virgo_create(&v, "./init");

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

  err = virgo_conf_args(v, argc, argv);
  if (err) {
    handle_error("Error in settings args", err);
    return EXIT_FAILURE;
  }

  /* Ensure we can read the zip file */
  fd = open(virgo_get_load_path(v), O_RDONLY);
  if (fd < 0) {
    fprintf(stderr, "Error: zip can't be opened %s\n", virgo_get_load_path(v));
    return EXIT_FAILURE;
  }
  else {
    close(fd);
  }

  virgo_log_infof(v, "Using bundle %s", virgo_get_load_path(v));

  err = virgo_init(v);
  if (err) {
    handle_error("Error in init", err);
    return EXIT_FAILURE;
  }

  err = virgo_agent_conf_set(v, "version", VERSION_FULL);
  if (err) {
    handle_error("Error setting agent version", err);
    return EXIT_FAILURE;
  }

  err = virgo_run(v);
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
    else {
      handle_error("Runtime Error", err);
    }
    return EXIT_FAILURE;
  }

  virgo_destroy(v);

  return 0;
}
