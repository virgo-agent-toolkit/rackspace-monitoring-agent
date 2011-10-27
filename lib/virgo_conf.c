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

#include "virgo.h"
#include "virgo__types.h"

#include <stdlib.h>
#include <string.h>

virgo_error_t*
virgo_conf_lua_load_path(virgo_t *v, const char *path)
{
  if (v->lua_load_path) {
    free((void*)v->lua_load_path);
  }

  v->lua_load_path = strdup(path);

  return VIRGO_SUCCESS;
}
