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
#include "virgo_versions.h"
#include "virgo_portable.h"
#include "virgo__types.h"
#include "uv.h"

virgo_error_t*
virgo__path_current_executable_path(virgo_t *v, char *buffer, size_t buffer_len) {
  uv_exepath(buffer, &buffer_len);
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_bundle_dir(virgo_t *v, char *buffer, size_t buffer_len) {
  if (v->lua_bundle_path) {
    strncpy(buffer, v->lua_bundle_path, buffer_len);
  } else {
#ifndef _WIN32
    strncpy(buffer, VIRGO_DEFAULT_BUNDLE_UNIX_DIRECTORY, buffer_len);
#else
    /* TODO: port */
    strncpy(buffer, "C:/temp/", buffer_len);
#endif
  }
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_exe_dir(virgo_t *v, char *buffer, size_t buffer_len) {
#ifndef _WIN32
  strncpy(buffer, VIRGO_DEFAULT_EXE_UNIX_DIRECTORY, buffer_len);
#else
  /* TODO: Port */
#endif
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_persistent_dir(virgo_t *v, char *buffer, size_t buffer_len) {
#ifndef _WIN32
  strncpy(buffer, VIRGO_DEFAULT_PERSISTENT_UNIX_DIRECTORY, buffer_len);
#else
  /* TODO: port */
  strncpy(buffer, "C:/temp/", buffer_len);
#endif
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_tmp_dir(virgo_t *v, char *buffer, size_t buffer_len) {
  char *tmp;
  virgo_error_t* err = virgo__temp_dir_get(&tmp);
  if (err) {
    return err;
  }

  strncpy(buffer, tmp, buffer_len);
  free(tmp);
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_library_dir(virgo_t *v, char *buffer, size_t buffer_len) {
#ifndef _WIN32
  strncpy(buffer, VIRGO_DEFAULT_LIBRARY_UNIX_DIRECTORY, buffer_len);
#else
  /* TODO: port */
#endif
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_runtime_dir(virgo_t *v, char *buffer, size_t buffer_len) {
#ifndef _WIN32
  strncpy(buffer, VIRGO_DEFAULT_RUNTIME_UNIX_DIRECTORY, buffer_len);
#else
  /* TODO: port */
#endif
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_config_dir(virgo_t *v, char *buffer, size_t buffer_len) {
#ifndef _WIN32
  strncpy(buffer, VIRGO_DEFAULT_CONFIG_UNIX_DIRECTORY, buffer_len);
#else
  /* TODO: port */
#endif
  return VIRGO_SUCCESS;
}

static int
is_bundle_file(const char *name) {
  return strstr(name, VIRGO_DEFAULT_BUNDLE_NAME_PREFIX) != NULL;
}

static int
is_exe_file(const char *name) {
  return strstr(name, VIRGO_DEFAULT_EXE_NAME_PREFIX) != NULL;
}

virgo_error_t*
virgo__path_zip_file(virgo_t *v, char *buffer, size_t buffer_len) {
  virgo_error_t *err = VIRGO_SUCCESS;
  char path[VIRGO_PATH_MAX];

  /* Fetch the BUNDLE directory */
  err = virgo__paths_get(v, VIRGO_PATH_BUNDLE_DIR, path, sizeof(path));
  if (err) {
    virgo_error_clear(err);
    goto default_bundle;
  }

  err = virgo__versions_latest_file(v,
                                    path,
                                    is_bundle_file,
                                    buffer,
                                    buffer_len);
  if (err) {
    virgo_error_clear(err);
    goto default_bundle;
  }

  return VIRGO_SUCCESS;

default_bundle:
  /* use the default path */
  strncpy(buffer, VIRGO_DEFAULT_ZIP_UNIX_PATH, buffer_len);
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__path_exe_file(virgo_t* v, char *buffer, size_t buffer_len) {
  virgo_error_t *err;
  char path[VIRGO_PATH_MAX];

  err = virgo__paths_get(v, VIRGO_PATH_EXE_DIR, path, sizeof(path));
  if (err) {
    return err;
  }

  err = virgo__versions_latest_file(v, path, is_exe_file, buffer, buffer_len);
  if (err) {
    /* on error, use the current executable */
    virgo_error_clear(err);
    goto default_path;
  }

  return VIRGO_SUCCESS;

default_path:
  err = virgo__paths_get(v, VIRGO_PATH_CURRENT_EXECUTABLE_PATH, buffer, buffer_len);
  return err;
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
  case VIRGO_PATH_EXE_DIR:
    err = virgo__path_exe_dir(v, buffer, buffer_len);
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
  case VIRGO_PATH_EXE:
    err = virgo__path_exe_file(v, buffer, buffer_len);
    break;
  default:
    err = virgo_error_create(-1, "Unknown path type");
  }
  return err;
}

