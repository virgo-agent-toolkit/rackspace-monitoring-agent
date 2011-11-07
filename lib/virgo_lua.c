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
#include "virgo_error.h"

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#ifdef _WIN32
#include <direct.h>
#endif

#include "luvit.h"
#include "uv.h"
#include "utils.h"
#include "luv.h"
#include "lconstants.h"
#include "lhttp_parser.h"
#include "lenv.h"

#ifndef PATH_MAX
#define PATH_MAX (8096)
#endif

static int
virgo__lua_luvit_getcwd(lua_State* L) {
  char getbuf[PATH_MAX + 1];
#ifdef _WIN32
  char *r = _getcwd(getbuf, sizeof(getbuf) - 1);
#else
  char *r = getcwd(getbuf, ARRAY_SIZE(getbuf) - 1);
#endif

  if (r == NULL) {
#ifdef _WIN32
    strerror_s(getbuf, sizeof(getbuf), errno);
    return luaL_error(L, "luvit_getcwd: %s\n", getbuf);
#else
    return luaL_error(L, "luvit_getcwd: %s\n",
                      strerror_r(errno, getbuf, sizeof(getbuf)));
#endif
  }

  getbuf[ARRAY_SIZE(getbuf) - 1] = '\0';
  lua_pushstring(L, r);
  return 1;
}

static int
virgo__lua_luvit_exit(lua_State* L) {
  int exit_code = luaL_checkint(L, 1);
  exit(exit_code);
  return 0;
}

static int
virgo__lua_luvit_print_stderr(lua_State* L) {
  const char* line = luaL_checkstring(L, 1);
  fprintf(stderr, "%s", line);
  return 0;
}

static void
virgo__lua_luvit_init(virgo_t *v)
{
  int index;
  lua_State *L = v->L;

  /* Pull up the preload table */
  lua_getglobal(L, "package");
  lua_getfield(L, -1, "preload");
  lua_remove(L, -2);

  /* Register http_parser */
  lua_pushcfunction(L, luaopen_http_parser);
  lua_setfield(L, -2, "http_parser");
  /* Register uv */
  lua_pushcfunction(L, luaopen_uv);
  lua_setfield(L, -2, "uv");
  /* Register env */
  lua_pushcfunction(L, luaopen_env);
  lua_setfield(L, -2, "env");
  /* Register constants */
  lua_pushcfunction(L, luaopen_constants);
  lua_setfield(L, -2, "constants");

  /* We're done with preload, put it away */
  lua_pop(L, 1);

  // Get argv
  lua_createtable (L, v->argc, 0);
  for (index = 0; index < v->argc; index++) {
    lua_pushstring (L, v->argv[index]);
    lua_rawseti(L, -2, index);
  }
  lua_setglobal(L, "argv");

  lua_pushcfunction(L, virgo__lua_luvit_getcwd);
  lua_setglobal(L, "getcwd");

  lua_pushcfunction(L, virgo__lua_luvit_exit);
  lua_setglobal(L, "exit_process");

  lua_pushcfunction(L, virgo__lua_luvit_print_stderr);
  lua_setglobal(L, "print_stderr");

  // Hold a reference to the main thread in the registry
  assert(lua_pushthread(L) == 1);
  lua_setfield(L, LUA_REGISTRYINDEX, "main_thread");

}

#ifndef stringify
#define xstringify(s) stringify(s)
#define stringify(s) #s
#endif

virgo_error_t*
virgo__lua_init(virgo_t *v)
{
  lua_State *L = luaL_newstate();

  v->L = L;

  lua_pushlightuserdata(L, v);
  lua_setfield(L, LUA_REGISTRYINDEX, "virgo.context");

  /* TODO: cleanup/standarize */
  lua_pushstring(L, stringify(VIRGO_OS));
  lua_setglobal(L, "virgo_os");

  luaL_openlibs(L);

  virgo__lua_loader_init(L);
  virgo__lua_debugger_init(L);

  virgo__lua_luvit_init(v);

  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__lua_run(virgo_t *v)
{
  int rv;
  const char *lua_err;

#if 1
  /**
   * Use this method of invoking the getglobal / getfield for init,
   * because someday we might want to compile out the Lua parser
   */

  lua_getglobal(v->L, "require");
  if (lua_type(v->L, -1) != LUA_TFUNCTION) {
    return virgo_error_create(VIRGO_EINVAL, "Lua require wasn't a function");
  }

  lua_pushliteral(v->L, "virgo_init");

  rv = lua_pcall(v->L, 1, 1, 0);
  if (rv != 0) {
    lua_err = lua_tostring(v->L, -1);
    return virgo_error_createf(VIRGO_EINVAL, "Failed to load init: %s", lua_err);
  }

  lua_getfield(v->L, -1, "run");
  lua_pushliteral(v->L, "monitoring-agent");
  /* virgo__lua_debug_stackdump(v->L, "example stack dump at run"); */

  rv = lua_pcall(v->L, 1, 1, 0);
  if (rv != 0) {
    lua_err = lua_tostring(v->L, -1);
    return virgo_error_createf(VIRGO_EINVAL, "Runtime error: %s", lua_err);
  }

#else
  rv = luaL_loadstring(v->L, "require('init'):run()");

  if (rv != 0) {
    lua_err = lua_tostring(v->L, -1);
    return virgo_error_createf(VIRGO_EINVAL, "Load Buffer Error: %s", lua_err);
  }

  rv = lua_pcall(v->L, 0, 0, 0);
  if (rv != 0) {
    lua_err = lua_tostring(v->L, -1);
    return virgo_error_createf(VIRGO_EINVAL, "Runtime error: %s", lua_err);
  }
#endif

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

