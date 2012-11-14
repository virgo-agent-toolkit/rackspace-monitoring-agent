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

extern "C" {
  #include "virgo__util.h"
  #include "virgo__types.h"
  #include "virgo_brand.h"
  #include "virgo_paths.h"
  #include "virgo.h"
  #include "stdio.h"

};

#include "../deps/breakpad/src/client/linux/handler/exception_handler.h"

google_breakpad::ExceptionHandler *virgo_global_exception_handler = NULL;

static bool dumpCallback(const char* dump_path, const char* minidump_id, void* context, bool succeeded) {
  int rv;
  FILE *fp;
  char *dump_file = NULL;
  virgo_t* v = *(virgo_t **)context;
  lua_State *L = v->L;

  rv = asprintf((char **) &dump_file, "%s/%s-crash-report-%s.dmp", dump_path, VIRGO_DEFAULT_NAME, minidump_id);
  if (rv != -1){
    printf("FATAL ERROR: Crash Dump written to: %s\n", dump_file);
  }
  if (!L){
    printf("No lua found.");
    return succeeded;
  }
  lua_getglobal(L, "dump_lua");
  rv = lua_pcall(L, 0, 1, 0);
  if (rv != 0) {
    printf("Error with lua dump: %s\n", lua_tostring(L, -1));
    return succeeded;
  }

  fp = fopen(dump_file, "ab");
  if (fp == NULL) {
    return succeeded;
  }

  fprintf(fp, "__5FY97Y1WBU7GPXCSIRS3T2EEHTSNJ6W183N8FUBFOD5LDWW06ZRBQB8AA8LA8BJD__\n%s", lua_tostring(L, -1));
  fclose(fp);

  return succeeded;
}

extern "C" {

  char path[VIRGO_PATH_MAX];

  virgo_t *v = NULL;
  virgo_error_t *err = virgo__paths_get(v, VIRGO_PATH_PERSISTENT_DIR, path, VIRGO_PATH_MAX);

  void virgo__crash_reporter_init(virgo_t **p_v) {
    virgo_global_exception_handler = new google_breakpad::ExceptionHandler(path, NULL, dumpCallback, (void *)p_v, true);
  };

  void
  virgo__crash_reporter_destroy() {
    delete virgo_global_exception_handler;
  };
};

