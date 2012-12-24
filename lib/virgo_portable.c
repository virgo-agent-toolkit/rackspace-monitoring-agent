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
#include "virgo_paths.h"
#include <string.h>

#ifdef WIN32
#include <io.h>
#include <fcntl.h>
#else
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#endif

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

  *outstr = calloc(1, sz + 1);
  if (*outstr == NULL) {
    return -1;
  }

  return vsnprintf(*outstr, sz, fmt, args);
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


/**
 * Based on the logic inside the Apache Portable Runtime, found here:
 *   <https://github.com/apache/apr/blob/trunk/file_io/unix/tempdir.c>
 */

static int test_tempdir(const char *temp_dir)
{
  char *tpath = NULL;
  int fd = -1;
  int rv = asprintf(&tpath, "%s"SEP"tmp.XXXXXX", temp_dir);

#ifdef _WIN32
  _mktemp_s(tpath, rv+1);
  fd = open(tpath, O_CREAT|O_WRONLY);
#else
  fd = mkstemp(tpath);
#endif

  if (fd == -1) {
    free(tpath);
    return 1;
  }

  rv = write(fd, "!", 1);
  if (rv != 1) {
    close(fd);
#ifdef _WIN32
    _unlink(tpath);
#endif
    free(tpath);
    return 1;
  }

  close(fd);
#ifdef _WIN32
  _unlink(tpath);
#endif
  free(tpath);
  return 0;
}

virgo_error_t*
virgo__temp_dir_get(char **temp_dir)
{
  const char *try_dirs[] = { "/tmp", "/usr/tmp", "/var/tmp" };
  const char *try_envs[] = { "TMPDIR", "TMP", "TEMP"};
  const char *dir;
  size_t i;

  /* Our goal is to find a temporary directory suitable for writing into.
  Here's the order in which we'll try various paths:

  $TMPDIR
  $TMP
  $TEMP
  "C:\TEMP"     (windows only)
  "SYS:\TMP"    (netware only)
  "/tmp"
  "/var/tmp"
  "/usr/tmp"
  P_tmpdir      (POSIX define)
  `pwd` 

  NOTE: This algorithm is basically the same one used by Python
  2.2's tempfile.py module.  */

  /* Try the environment first. */
  for (i = 0; i < (sizeof(try_envs) / sizeof(const char *)); i++) {
    char *value;
    value = getenv(try_envs[i]);
    if (value) {
      size_t len = strlen(value);
      if (len && (len < VIRGO_PATH_MAX) && !test_tempdir(value)) {
        dir = value;
        goto end;
      }
    }
  }

#ifdef WIN32
  /* Next, on Win32, try the C:\TEMP directory. */
  if (!test_tempdir("C:\\TEMP")) {
    dir = "C:\\TEMP";
    goto end;
  }
#endif
#ifdef NETWARE
  /* Next, on NetWare, try the SYS:/TMP directory. */
  if (!test_tempdir("SYS:/TMP")) {
    dir = "SYS:/TMP";
    goto end;
  }
#endif

  /* Next, try a set of hard-coded paths. */
  for (i = 0; i < (sizeof(try_dirs) / sizeof(const char *)); i++) {
    if (!test_tempdir(try_dirs[i])) {
      dir = try_dirs[i];
      goto end;
    }
  }

#ifdef P_tmpdir
  /* 
  * If we have it, use the POSIX definition of where 
  * the tmpdir should be 
  */
  if (!test_tempdir(P_tmpdir)) {
    dir = P_tmpdir;
    goto end;
  }
#endif

  return virgo_error_create(VIRGO_EINVAL, "Unable to detect temporary directory.");
end:
  *temp_dir = strdup(dir);
  return VIRGO_SUCCESS;
}
