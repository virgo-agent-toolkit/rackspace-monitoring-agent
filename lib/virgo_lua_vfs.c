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
#include "virgo__lua.h"

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "luaconf.h"

#include "unzip.h"

#include <stdlib.h>
#include <string.h>

#define ZIPFILEHANDLE "lminizip"

static unzFile*
newunzFile(lua_State *L)
{
  unzFile* zip = (unzFile*)lua_newuserdata(L, sizeof(unzFile*));
  *zip = NULL;
  luaL_getmetatable(L, ZIPFILEHANDLE);
  lua_setmetatable(L, -2);
  return zip;
}

static unzFile*
zip_context(lua_State *L, int findex) {
  unzFile* f = (unzFile*)luaL_checkudata(L, findex, ZIPFILEHANDLE);
  if (f == NULL) {
    luaL_argerror(L, findex, "bad vfs context");
  }
  return f;
}

static int
vfs_open(lua_State *L) {
  virgo_t *v = virgo__lua_context(L);
  unzFile *zip = newunzFile(L);
  *zip = unzOpen(v->lua_load_path);
  return 1;
}

static int
vfs_close(lua_State *L) {
  unzFile *zip = luaL_checkudata(L, 1, ZIPFILEHANDLE);
  if (*zip) {
    unzCloseCurrentFile(*zip);
    unzClose(*zip);
  }
  return 0;
}

static int
vfs_gc(lua_State *L) {
  return vfs_close(L);
}

static int
vfs_read(lua_State *L) {
  struct unz_file_info_s finfo;
  unzFile *zip;
  const char *name;
  int rv;
  char *buf;
  size_t len;

  zip = zip_context(L, 1);
  name = luaL_checkstring(L, 2);

  if (name[0] == '/') {
    name++;
  }

  rv = unzLocateFile(*zip, name, 1);
  if (rv != UNZ_OK) {
    lua_pushnil(L);
    lua_pushfstring(L, "could not open file '%s'", name);
    return 2;
  }

  rv = unzGetCurrentFileInfo(*zip, &finfo, NULL, 0, NULL, 0, NULL, 0);
  if (rv != UNZ_OK) {
    lua_pushnil(L);
    lua_pushfstring(L, "could not get current file info '%s'", name);
    return 2;
  }

  rv = unzOpenCurrentFile(*zip);
  if (rv != UNZ_OK) {
    lua_pushnil(L);
    lua_pushfstring(L, "could not open current file '%s'", name);
    return 2;
  }

  buf = malloc(finfo.uncompressed_size);
  len = finfo.uncompressed_size;

  rv = unzReadCurrentFile(*zip, buf, len);
  if (rv != (int)len) {
    free(buf);
    lua_pushnil(L);
    lua_pushfstring(L, "could not read current file '%s'", name);
    return 2;
  }

  lua_pushlstring(L, buf, len);
  free(buf);
  return 1;
}

static int
vfs_exists(lua_State *L) {
  int rv;
  unzFile *zip;
  const char *name;

  zip = zip_context(L, 1);
  name = luaL_checkstring(L, 2);
  if (name[0] == '/') {
    name++;
  }

  rv = unzLocateFile(*zip, name, 1);
  if (rv == UNZ_OK) {
    lua_pushboolean(L, 1);
  } else {
    lua_pushnil(L);
  }
  return 1;
}

static const luaL_reg fvfslib[] = {
  {"exists", vfs_exists},
  {"read", vfs_read},
  {"__gc", vfs_gc},
  {NULL, NULL}
};

static const luaL_reg vfslib[] = {
  {"open", vfs_open},
  {NULL, NULL}
};

int
virgo__lua_vfs_init(lua_State *L)
{
  luaL_newmetatable(L, ZIPFILEHANDLE);
  lua_pushliteral(L, "__index");
  lua_pushvalue(L, -2);  /* push metatable */
  lua_rawset(L, -3);  /* metatable.__index = metatable */
  luaL_openlib(L, NULL, fvfslib, 0);
  lua_pushvalue(L, -1);

  luaL_openlib(L, "VFS", vfslib, 1);
  return 1;
}
