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

#ifndef _virgo__paths_h_
#define _virgo__paths_h_

typedef enum {
  VIRGO_PATH_CURRENT_EXECUTABLE_PATH,
  VIRGO_PATH_BUNDLE_DIR,
  VIRGO_PATH_EXE_DIR,
  VIRGO_PATH_PERSISTENT_DIR,
  VIRGO_PATH_TMP_DIR,
  VIRGO_PATH_LIBRARY_DIR,
  VIRGO_PATH_CONFIG_DIR,
  VIRGO_PATH_RUNTIME_DIR,
  VIRGO_PATH_BUNDLE,
  VIRGO_PATH_EXE,
} virgo_path_e;

#ifdef _WIN32
  #ifndef SEP
    #define SEP "\\"
  #endif
#else
  #ifndef SEP
    #define SEP "/"
  #endif
#endif

virgo_error_t*
virgo__paths_get(virgo_t *v, virgo_path_e type, char *buffer, size_t buffer_len);

#ifdef MAX_PATH
#define VIRGO_PATH_MAX MAX_PATH
#endif

#ifdef PATH_MAX
#define VIRGO_PATH_MAX PATH_MAX
#endif

#endif
