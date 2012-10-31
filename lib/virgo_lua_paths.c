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
#include "virgo_paths.h"
#include "virgo_error.h"
#include "virgo__types.h"
#include "virgo__lua.h"

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "luaconf.h"

#include <limits.h>
#include <stdlib.h>

static int
paths_get(lua_State *L) {
  char buffer[VIRGO_PATH_MAX];
  virgo_t *v = virgo__lua_context(L);
  int type = luaL_checkinteger(L, 1);
  virgo_error_t *err = virgo__paths_get(v, type, buffer, sizeof(buffer));
  if (err) {
    return virgo_error_luaL(L, err);
  }
  lua_pushstring(L, buffer);
  return 1;
}

static int
paths_set_bundle(lua_State *L) {
  virgo_t *v = virgo__lua_context(L);
  const char *path = luaL_checkstring(L, 1);
  virgo_conf_lua_bundle_path(v, path);
  return 0;
}

static const luaL_reg virgo_paths[] = {
  {"get", paths_get},
  {"set_bundle_path", paths_set_bundle},
  {NULL, NULL}
};

int
virgo__lua_paths(lua_State *L)
{
  luaL_openlib(L, "virgo_paths", virgo_paths, 1);
  VIRGO_DEFINE_CONSTANT(L, VIRGO_PATH_CURRENT_EXECUTABLE_PATH);
  VIRGO_DEFINE_CONSTANT(L, VIRGO_PATH_BUNDLE_DIR);
  VIRGO_DEFINE_CONSTANT(L, VIRGO_PATH_RUNTIME_DIR);
  VIRGO_DEFINE_CONSTANT(L, VIRGO_PATH_PERSISTENT_DIR);
  VIRGO_DEFINE_CONSTANT(L, VIRGO_PATH_TMP_DIR);
  VIRGO_DEFINE_CONSTANT(L, VIRGO_PATH_LIBRARY_DIR);
  VIRGO_DEFINE_CONSTANT(L, VIRGO_PATH_CONFIG_DIR);
  VIRGO_DEFINE_CONSTANT(L, VIRGO_PATH_BUNDLE);
  VIRGO_DEFINE_CONSTANT(L, VIRGO_PATH_EXE_DIR);
  return 1;
}
