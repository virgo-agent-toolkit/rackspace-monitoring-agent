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
#include "virgo_brand.h"
#include "virgo_paths.h"
#include "virgo_error.h"
#include "virgo__types.h"
#include "uv.h"

#include <stdlib.h>
#include <ctype.h>

virgo_error_t*
virgo__path_current_executable_path(virgo_t *v, char *buffer, size_t buffer_len) {
  uv_exepath(buffer, &buffer_len);
  return VIRGO_SUCCESS;
}

#ifndef _WIN32

virgo_error_t*
virgo__path_bundle_dir(virgo_t *v, char *buffer, size_t buffer_len) {
  if (v->lua_bundle_path) {
    strncpy(buffer, v->lua_bundle_path, buffer_len);
  } else {
    strncpy(buffer, VIRGO_DEFAULT_BUNDLE_UNIX_DIRECTORY, buffer_len);
  }
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_persistent_dir(virgo_t *v, char *buffer, size_t buffer_len) {
  strncpy(buffer, VIRGO_DEFAULT_PERSISTENT_UNIX_DIRECTORY, buffer_len);
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_tmp_dir(virgo_t *v, char *buffer, size_t buffer_len) {
  strncpy(buffer, VIRGO_DEFAULT_TMP_UNIX_DIRECTORY, buffer_len);
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_library_dir(virgo_t *v, char *buffer, size_t buffer_len) {
  strncpy(buffer, VIRGO_DEFAULT_LIBRARY_UNIX_DIRECTORY, buffer_len);
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_runtime_dir(virgo_t *v, char *buffer, size_t buffer_len) {
  strncpy(buffer, VIRGO_DEFAULT_RUNTIME_UNIX_DIRECTORY, buffer_len);
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_config_dir(virgo_t *v, char *buffer, size_t buffer_len) {
  strncpy(buffer, VIRGO_DEFAULT_CONFIG_UNIX_DIRECTORY, buffer_len);
  return VIRGO_SUCCESS;
}

#endif

#ifdef _WIN32

virgo_error_t*
virgo__path_bundle_dir(virgo_t *v, char *buffer, size_t buffer_len) {
  strncpy(buffer, "C:/temp/", buffer_len);
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_persistent_dir(virgo_t *v, char *buffer, size_t buffer_len) {
  strncpy(buffer, "C:/temp/", buffer_len);
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_tmp_dir(virgo_t *v, char *buffer, size_t buffer_len) {
  strncpy(buffer, "C:/temp/", buffer_len);
  return VIRGO_SUCCESS;
}

#endif

/* Public domain version comparison
 * http://codingcastles.blogspot.com/2009/05/comparing-version-numbers.html
 */
static int
compare_versions(const char *a, const char *b) {
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

static int
is_bundle_file(const char *name) {
  return strstr(name, VIRGO_DEFAULT_BUNDLE_NAME_PREFIX) != NULL;
}

static virgo_error_t*
compare_files(char *a, char *b, int *comparison) {
  *comparison = compare_versions(a, b);
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_zip_file(virgo_t *v, char *buffer, size_t buffer_len) {
  uv_fs_t readdir_req;
  virgo_error_t *err = VIRGO_SUCCESS;
  char *latest = NULL;
  char path[PATH_MAX];
  char *ptr;
  int i, rc;

  /* Fetch the BUNDLE directory */
  err = virgo__paths_get(v, VIRGO_PATH_BUNDLE_DIR, path, sizeof(path));
  if (err) {
    virgo_error_clear(err);
    goto default_bundle;
  }

  rc = uv_fs_readdir(uv_default_loop(), &readdir_req, path, 0, NULL);

  if (!rc) {
    goto default_bundle;
  }

  ptr=readdir_req.ptr;
  for (i=0; i < rc; i++) {
    int comparison;

    /* Verify this is a bundle filename */
    if (!is_bundle_file(ptr)) {
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
    goto default_bundle;
  }

  /* Save off the path */
  snprintf(buffer, buffer_len, "%s%s%s", path, SEP, latest);

  return VIRGO_SUCCESS;

default_bundle:
  /* use the default path */
  strncpy(buffer, VIRGO_DEFAULT_ZIP_UNIX_PATH, buffer_len);
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__paths_get(virgo_t *v, virgo_path_e type, char *buffer, size_t buffer_len) {
  virgo_error_t *err = VIRGO_SUCCESS;
  switch(type) {
  case VIRGO_PATH_CURRENT_EXECUTABLE_PATH:
    err = virgo__path_current_executable_path(v, buffer, buffer_len);
    break;
  case VIRGO_PATH_BUNDLE_DIR:
    err = virgo__path_bundle_dir(v, buffer, buffer_len);
    break;
  case VIRGO_PATH_PERSISTENT_DIR:
    err = virgo__path_persistent_dir(v, buffer, buffer_len);
    break;
  case VIRGO_PATH_TMP_DIR:
    err = virgo__path_tmp_dir(v, buffer, buffer_len);
    break;
  case VIRGO_PATH_LIBRARY_DIR:
    err = virgo__path_library_dir(v, buffer, buffer_len);
    break;
  case VIRGO_PATH_CONFIG_DIR:
    err = virgo__path_config_dir(v, buffer, buffer_len);
    break;
  case VIRGO_PATH_RUNTIME_DIR:
    err = virgo__path_runtime_dir(v, buffer, buffer_len);
    break;
  case VIRGO_PATH_BUNDLE:
    err = virgo__path_zip_file(v, buffer, buffer_len);
    break;
  default:
    err = virgo_error_create(-1, "Unknown path type");
  }
  return err;
}

