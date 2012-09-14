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

#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>

#include "virgo.h"
#include "virgo_error.h"
#include "virgo_paths.h"
#include "virgo_versions.h"

/* Public domain version comparison
 * http://codingcastles.blogspot.com/2009/05/comparing-version-numbers.html
 */
int
virgo__versions_compare(const char *a, const char *b) {
  long int num_a, num_b;
  char *next_a, *next_b;
  while (*a && *b) {
    while (*a && *b && !isdigit(*a) && !isdigit(*b)) {
      if (*a != *b) {
        if (*a == '~') return -1;
        if (*b == '~') return 1;
        return *a < *b ? -1 : 1;
      }
      a++;
      b++;
    }
    if (*a && *b && (!isdigit(*a) || !isdigit(*b))) {
      if (*a == '~') return -1;
      if (*b == '~') return 1;
      return isdigit(*a) ? -1 : 1;
    }

    num_a = strtol(a, &next_a, 10);
    num_b = strtol(b, &next_b, 10);
    if (num_a != num_b) {
      return num_a < num_b ? -1 : 1;
    }
    a = next_a;
    b = next_b;
  }
  if (!*a && !*b) {
    return 0;
  } else if (*a) {
    return *a == '~' ? -1 : 1;
  } else {
    return *b == '~' ? 1 : -1;
  }
}

static virgo_error_t*
compare_files(char *a, char *b, int *comparison) {
  *comparison = virgo__versions_compare(a, b);
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__versions_latest_file(virgo_t *v, const char *path, is_file_cmp file_compare,
                            char *buffer, size_t buffer_len) {
  char *latest = NULL;
  char *ptr;
  int rc, i;
  uv_fs_t readdir_req;
  virgo_error_t *err;

  rc = uv_fs_readdir(uv_default_loop(), &readdir_req, path, 0, NULL);
  if (!rc) {
    return virgo_error_create(-1, "readdir returned 0");
  }

  ptr = readdir_req.ptr;
  for (i=0; i < rc; i++) {
    int comparison;

    /* Verify this is a bundle filename */
    if (!file_compare(ptr)) {
      goto next;
    }

    /* Initial pass */
    if (!latest) {
      latest = ptr;
      goto next;
    }

    /* Perform the comparison */
    err = compare_files(ptr, latest, &comparison);
    if (err) {
      virgo_error_clear(err);
      goto next;
    }

    /* If comparison returns 1, then the versions are greater */
    if (comparison == 1) {
      latest = ptr;
    }

next:
    ptr = ptr + strlen(ptr) + 1;
  }

  if (!latest) {
    uv_fs_req_cleanup(&readdir_req);
    return virgo_error_create(VIRGO_ENOFILE, "zero files");
  }

  /* Save off the path */
  snprintf(buffer, buffer_len, "%s%s%s", path, SEP, latest);
  uv_fs_req_cleanup(&readdir_req);

  return VIRGO_SUCCESS;
}
