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
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "luaconf.h"

#ifndef _virgo__lua_h_
#define _virgo__lua_h_

#ifndef LUA_OK
/* Added in Lua 5.2, not in 5.1 */
#define LUA_OK (0)
#endif

virgo_error_t* virgo__lua_init(virgo_t *v);
virgo_error_t* virgo__lua_run(virgo_t *v);
void virgo__lua_destroy(virgo_t *v);

virgo_t* virgo__lua_context(lua_State *L);

void virgo__lua_loader_init(lua_State *L);

int virgo__lua_debugger_init(lua_State *L);
void virgo__lua_debug_stackdump(lua_State *L, const char *msg);
int virgo__lua_debug_stackwalk(lua_State *l);
int virgo__lua_vfs_init(lua_State *L);
int virgo__lua_logging_open(lua_State *L);

#define VIRGO_DEFINE_CONSTANT_ALIAS(L, constant, alias) \
  lua_pushnumber(L, constant);             \
  lua_setfield(L, -2, alias)

#define VIRGO_DEFINE_CONSTANT(L, constant) \
  lua_pushnumber(L, constant);             \
  lua_setfield(L, -2, #constant)


#endif /* _virgo__lua_h_ */
