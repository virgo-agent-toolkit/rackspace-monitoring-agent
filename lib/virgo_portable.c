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
#include "virgo_portable.h"
#include <string.h>

#ifdef VIRGO_WANT_ASPRINTF

#include <stdio.h>
#include <stdarg.h>
#include <malloc.h>

int virgo_vasprintf(char **outstr, const char *fmt, va_list args)
{
  size_t sz;
  sz = vsnprintf(NULL, 0, fmt, args);

  if (sz < 0) {
    return sz;
  }

  *outstr = malloc(sz + 1);
  if (*outstr == NULL) {
    return -1;
  }

  return vsnprintf(*outstr, sz + 1, fmt, args);
}

int virgo_asprintf(char **outstr, const char *fmt, ...)
{
  int rv;
  va_list args;

  va_start(args, fmt);
  rv = virgo_vasprintf(outstr, fmt, args);
  va_end(args);

  return rv;
}

#endif

char* virgo_basename(char *name)
{
  char* s = strrchr(name, '/');
  return s ? (s + 1) : (char*)name;
}

