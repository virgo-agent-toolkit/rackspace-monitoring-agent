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

#ifdef LINUX
#define _GNU_SOURCE
#endif

#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#include <strsafe.h>
#endif

#include "virgo_error.h"
#include "virgo_portable.h"

virgo_error_t*
virgo_error_create_impl(virgo_status_t err,
                        int os_error,
                        int copy_msg,
                        const char *msg,
                        uint32_t line,
                        const char *file)
{
  virgo_error_t *e;

  e = malloc(sizeof(*e));

  e->err = err;
  if (os_error == 0) {
    if (copy_msg) {
      e->msg = strdup(msg);
    }
    else {
      e->msg = msg;
    }
  }
  else {
#ifdef _WIN32
    char buf[128];
    FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                   NULL,
                   os_error,
                   0,
                   buf, sizeof(buf), NULL);

      virgo_asprintf((char**)&e->msg, "%s: (%d) %s", msg, os_error, buf);
#else
    char buf[128];

    strerror_r(os_error, buf, sizeof(buf));

    virgo_asprintf((char**)&e->msg, "%s: (%d) %s", msg, os_error, buf);
#endif
  }
  e->line = line;
  e->file = strdup(file);

  return e;
}

virgo_error_t *
virgo_error_createf_impl(virgo_status_t err,
                         int os_error,
                         uint32_t line,
                         const char *file,
                         const char *fmt,
                         ...)
{
  char *msg = NULL;
  int rv;
  int copy = 0;
  virgo_error_t *err_out;
  va_list ap;

  va_start(ap, fmt);
  rv = vasprintf((char **) &msg, fmt, ap);
  va_end(ap);

  if (rv == -1) {
    copy = 1;
    msg = "vasprintf inside virgo_error_createf_impl returned -1, you likely have larger problems here";
  }

  err_out = virgo_error_create_impl(err, os_error, copy, msg, line, file);

  return err_out;
}

void
virgo_error_clear(virgo_error_t *err)
{
    if (err) {
        free((void *) err->msg);
        free((void *) err->file);
        free(err);
    }
}
