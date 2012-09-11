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
#include "virgo_error.h"
#include "virgo__types.h"
#include "virgo__paths.h"
#include "uv.h"

#include <string.h>

virgo_error_t*
virgo__path_current_executable_path(virgo_t *v, char *buffer, size_t buffer_len) {
  uv_exepath(buffer, &buffer_len);
  return VIRGO_SUCCESS;
}

#ifndef _WIN32

virgo_error_t*
virgo__path_bundle_dir(virgo_t *v, char *buffer, size_t buffer_len) {
  strncpy(buffer, VIRGO_DEFAULT_BUNDLE_UNIX_DIRECTORY, buffer_len);
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
  default:
    err = virgo_error_create(-1, "Unknown path type");
  }
  return err;
}

