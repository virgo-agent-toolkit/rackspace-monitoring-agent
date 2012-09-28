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
#include "virgo__types.h"
#include "virgo__time.h"
#include "virgo__lua.h"
#include "virgo__util.h"
#include "virgo_paths.h"
#include "virgo_error.h"

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "luajit.h"

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
#include "lyajl.h"
#include "lcrypto.h"

extern int luaopen_sigar (lua_State *L);

static void
virgo__lua_luvit_init(virgo_t *v)
{
  lua_State *L = v->L;

  luvit_init(L, uv_default_loop(), v->argc, v->argv);

  /* Pull up the preload table */
  lua_getglobal(L, "package");
  lua_getfield(L, -1, "preload");
  lua_remove(L, -2);

  /* Register constants */
  lua_pushcfunction(L, virgo__lua_logging_open);
  lua_setfield(L, -2, "logging");

  lua_pop(L, 1);
}

static void
virgo__set_virgo_key(lua_State *L, const char *key, const char *value)
{
  /* Set virgo.os */
  lua_getglobal(L, "virgo");
  lua_pushstring(L, key);
  lua_pushstring(L, value);
  lua_settable(L, -3);
}

static int
virgo__lua_force_crash(lua_State *L) {
  volatile int* a = (int*)(NULL);
  *a = 1;
  return 0;
}


#ifdef _WIN32

#include "Shlwapi.h"

static int
virgo__lua_win32_get_associated_exe(lua_State *L) {
  DWORD exePathLen = MAX_PATH;
  HRESULT hr;
  TCHAR exePath[ MAX_PATH ] = { 0 };
  virgo_t* v = virgo__lua_context(L);
  const char *extension = luaL_checkstring(L, 1);

  hr = AssocQueryString(0, ASSOCSTR_EXECUTABLE,
                        extension, "open",
                        exePath, &exePathLen);
  if (hr < 0) {
    lua_pushnil(L);
    lua_pushfstring(L, "could not find file association: '%d'", hr);
    return 2;
  }

  lua_pushlstring(L, exePath, exePathLen - 1);
  return 1;
}
#endif

virgo_error_t*
virgo__lua_init(virgo_t *v)
{
  lua_State *L = luaL_newstate();

#if 0
  /* Can disable the JIT if you think it will allow better debugging */
  luaJIT_setmode(L, 0, LUAJIT_MODE_ENGINE|LUAJIT_MODE_OFF);
#endif

  v->L = L;

  lua_pushlightuserdata(L, v);
  lua_setfield(L, LUA_REGISTRYINDEX, "virgo.context");

  /* Create global config object called virgo */
  lua_newtable(L);
  lua_setglobal(L, "virgo");

  lua_getglobal(L, "virgo");
  lua_pushcfunction(L, virgo__lua_force_crash);
  lua_setfield(L, -2, "force_crash");

  lua_getglobal(L, "virgo");
  lua_pushcfunction(L, virgo_time_now);
  lua_setfield(L, -2, "gmtnow");

#ifdef _WIN32
  lua_getglobal(L, "virgo");
  lua_pushcfunction(L, virgo__lua_win32_get_associated_exe);
  lua_setfield(L, -2, "win32_get_associated_exe");
#endif

  virgo__set_virgo_key(L, "os", VIRGO_OS);
  virgo__set_virgo_key(L, "version", VIRGO_VERSION);
  virgo__set_virgo_key(L, "platform", VIRGO_PLATFORM);
  virgo__set_virgo_key(L, "default_name", VIRGO_DEFAULT_NAME);
  virgo__set_virgo_key(L, "default_config_filename", VIRGO_DEFAULT_CONFIG_FILENAME);

  luaL_openlibs(L);
  luaopen_sigar(L);

  virgo__lua_paths(L);
  virgo__lua_vfs_init(L);
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

  virgo__set_virgo_key(v->L, "loaded_zip_path", v->lua_load_path);

#if 1
  /**
   * Use this method of invoking the getglobal / getfield for init,
   * because someday we might want to compile out the Lua parser
   */

  lua_getglobal(v->L, "require");
  if (lua_type(v->L, -1) != LUA_TFUNCTION) {
    return virgo_error_create(VIRGO_EINVAL, "Lua require wasn't a function");
  }

  lua_pushliteral(v->L, "virgo-init");

  rv = lua_pcall(v->L, 1, 1, 0);
  if (rv != 0) {
    lua_err = lua_tostring(v->L, -1);
    return virgo_error_createf(VIRGO_EINVAL, "Failed to load init from %s: %s", v->lua_load_path, lua_err);
  }

  lua_getfield(v->L, -1, "run");
  lua_pushstring(v->L, v->lua_default_module);
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

