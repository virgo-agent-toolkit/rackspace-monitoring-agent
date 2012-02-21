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
#include <stdio.h>
#include <stdlib.h>

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
  printf("Usage: monitoring-agent [options] \n"
         "\n"
         "Options:\n"
         "  -v, --version         print monitoring-agent's version\n"
         "  -c, --config=val      Set configuration file path. Default: /etc/rackspace.cfg\n"
         "  -e=val                Entry module.\n"
         "  -z, --zip=val         Path to Zip Bundle.\n"
         "\n"
         "Documentation can be found at http://monitoring.api.rackspacecloud.com/\n");
  fflush(stdout);

}

int main(int argc, char* argv[])
{
  virgo_t *v;
  virgo_error_t *err;

  err = virgo_create(&v, "monitoring");

  if (err) {
    handle_error("Error in startup", err);
    return EXIT_FAILURE;
  }

  /* default filename */
  err = virgo_conf_lua_load_path(v, "monitoring.zip");
  if (err) {
    handle_error("Error in setting lua load path", err);
    return EXIT_FAILURE;
  }

  /* TODO: read path from config file */
  err = virgo_conf_args(v, argc, argv);
  if (err) {
    handle_error("Error in settings args", err);
    return EXIT_FAILURE;
  }

  err = virgo_run(v);
  if (err) {
    if (err->err == VIRGO_EHELPREQ) {
      show_help();
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


