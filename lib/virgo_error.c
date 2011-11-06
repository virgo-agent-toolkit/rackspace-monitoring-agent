/*
 *  Copyright 2011 Rackspace
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

#include "virgo_error.h"
#include "virgo_portable.h"

virgo_error_t*
virgo_error_create_impl(virgo_status_t err,
                         const char *msg,
                         uint32_t line,
                         const char *file)
{
  virgo_error_t *e;

  e = malloc(sizeof(*e));

  e->err = err;
  e->msg = strdup(msg);
  e->line = line;
  e->file = strdup(file);

  return e;
}

virgo_error_t *
virgo_error_createf_impl(virgo_status_t err,
                          uint32_t line,
                          const char *file,
                          const char *fmt,
                          ...)
{
  int rv;
  virgo_error_t *e;
  va_list ap;

  e = malloc(sizeof(*e));

  e->err = err;

  va_start(ap, fmt);
  rv = vasprintf((char **) &e->msg, fmt, ap);
  va_end(ap);

  if (rv == -1) {
    e->msg = strdup("vasprintf inside virgo_error_createf_impl returned -1, you likely have larger problems here");
  }

  e->line = line;
  e->file = strdup(file);
  return e;
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
