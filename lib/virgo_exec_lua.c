/*
 *  Copyright 2013 Rackspace
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
#include "virgo__lua.h"
#include "virgo_error.h"
#include "virgo_paths.h"
#include "virgo_exec.h"
#include "virgo_versions.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "luaconf.h"
static int
is_new_exe(lua_State *L) {
  virgo_t *v = virgo__lua_context(L);
  const char *path = luaL_checkstring(L, 1);
  const char *version = luaL_checkstring(L, 2);
  lua_pushboolean(L, virgo__is_new_exe(path, version));
  return 1;
}
static const luaL_reg virgo_exec[] = {
  {"is_new_exe", is_new_exe},
  {NULL, NULL}
};
int
virgo__lua_exec(lua_State *L)
{
  luaL_openlib(L, "virgo_exec", virgo_exec, 1);
  return 1;
}
