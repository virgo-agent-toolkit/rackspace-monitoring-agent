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
#include "luaconf.h"

#include <stdlib.h>

static int
virgo__lua_loader_checkload(lua_State *L, int stat, const char *filename) {

  if (stat) {  /* module loaded successfully? */
    lua_pushstring(L, filename);  /* will be 2nd argument to module */
    return 2;  /* return open function and file name */
  }
  else {
    return luaL_error(L, "error loading virgo module " LUA_QS
                         " from file " LUA_QS ":\n\t%s",
                          lua_tostring(L, 1), filename, lua_tostring(L, -1));
  }
}

static int
virgo__lua_loader_loadit(lua_State *L) {
  int status;
  char *buf = "";
  size_t len = 0;
  virgo_t* v = virgo__lua_context(L);
  const char *name = luaL_checkstring(L, 1);

  /* TODO: find in minizip */

  status = luaL_loadbuffer(L, buf, len, name);

  return virgo__lua_loader_checkload(L, status == LUA_OK, name);
}

void
virgo__lua_loader_init(lua_State *L)
{
  int top;

  top = lua_gettop(L);
  lua_getglobal(L, "package");

  if (lua_type(L, -1) != LUA_TTABLE) {
    abort();
  }

  lua_pushliteral(L, "searchers");
  lua_gettable(L, -2);

  if(lua_type(L, -1) != LUA_TTABLE) {
    abort();
  }

  lua_pushnumber(L, lua_rawlen(L, -1) + 1);
  lua_pushcfunction(L, virgo__lua_loader_loadit);
  lua_settable(L, -3);
}

