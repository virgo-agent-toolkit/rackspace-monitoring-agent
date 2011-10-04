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
#include "virgo__lua.h"

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"


virgo_error_t*
virgo__lua_init(virgo_t *v)
{
  lua_State *L = luaL_newstate();

  lua_pushlightuserdata(L, v);
  lua_setfield(L, LUA_REGISTRYINDEX, "virgo.context");

  luaL_openlibs(L);

  v->L = L;

  return VIRGO_SUCCESS;
}

void
virgo__lua_destroy(virgo_t *v)
{
  if (v->L) {
    lua_close(v->L);
    v->L = NULL;
  }
}

virgo_t*
virgo__lua_context(lua_State *L)
{
  virgo_t* v;

  lua_getfield(L, LUA_REGISTRYINDEX, "virgo.context");
  v = lua_touserdata(L, -1);
  lua_pop(L, 1);

  return v;
}
