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
#include "virgo_error.h"
#include "virgo__types.h"
#include "virgo__conf.h"

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include <assert.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>

#define VIRGO_DEFAULT_CONFIG_UNIX_FILENAME "/etc/rackspace.conf"

virgo_error_t*
virgo_conf_lua_load_path(virgo_t *v, const char *path)
{
  if (v->lua_load_path) {
    free((void*)v->lua_load_path);
  }

  v->lua_load_path = strdup(path);

  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo_conf_args(virgo_t *v, int argc, char** argv)
{
  v->argc = argc;
  v->argv = argv;

  return VIRGO_SUCCESS;
}

static void
nuke_newlines(char *p)
{
  size_t i;
  size_t l = strlen(p);
  for (i = 0; i < l; i++) {
    if (p[i] == '\n') {
      p[i] = '\0';
    }
    if (p[i] == '\r') {
      p[i] = '\0';
    }
  }
}

static char*
next_chunk(char **x_p)
{
  char *p = *x_p;

  while (isspace(p[0])) { p++;};

  nuke_newlines(p);

  *x_p = p;
  return strdup(p);
}

static void
conf_parse(lua_State *L, FILE *fp)
{
  char buf[8096];
  char *p = NULL;
  while ((p = fgets(buf, sizeof(buf), fp)) != NULL) {
    char *value, *key;

    /* comment lines */
    if (p[0] == '#') {
      continue;
    }

    while (isspace(p[0])) { p++;};

    /* calculate key/value pairs */
    key = next_chunk(&p);
    p = key;
    while(!isspace(p[0])) { p++;};
    *p = '\0'; /* null terminate key */
    p++;
    while(isspace(p[0])) { p++;};
    value = p;

    lua_pushstring(L, value);
    lua_setfield(L, -2, key);
    free(key);
  }
}

static const char*
get_config_path(virgo_t *v)
{
  int i = 0;
  int argc = v->argc;
  char **argv = v->argv;
  const char *arg;

  while (i < argc) {
    arg = argv[i];

    if (strcmp(arg, "-c") == 0 || strcmp(arg, "--config") == 0) {
      const char *p = argv[i+1];
      if (p) {
        return p;
      }
    }
    i++;
  }

  return VIRGO_DEFAULT_CONFIG_UNIX_FILENAME;
}

const char*
virgo__conf_get(virgo_t *v, const char *key)
{
  const char *value = NULL;
  lua_State *L = v->config->L;
  int before = lua_gettop(L);

  lua_getglobal(L, "config");
  lua_pushstring(L, key);
  lua_gettable(L, -2);
  value = lua_tostring(L, -1);
  lua_pop(L, 2);
  assert(lua_gettop(L) == before);

  return value;
}

void
virgo__conf_destroy(virgo_t *v)
{
  lua_close(v->config->L);
  free(v->config);
  v->config = NULL;
}

virgo_error_t*
virgo__conf_init(virgo_t *v)
{
  FILE *fp;
  lua_State *L;
  /* TODO: respect prefix */
#ifdef _WIN32
  char *programfiles;
  char path[512];
#else
  const char *path;
#endif

#ifdef _WIN32
  programfiles = getenv("ProgramFiles");
  if (programfiles == NULL) {
    return virgo_error_create(VIRGO_EINVAL, "Unable to get environment variable: \"ProgramFiles\"\n");
  }
  sprintf(path, "%s\\Rackspace Agent\\etc\\rackspace.cfg", programfiles);
  fp = fopen(path, "r");
#else
  path = get_config_path(v);
  fp = fopen(path, "r");
#endif
  if (fp == NULL) {
    return virgo_error_createf(VIRGO_EINVAL, "Unable to read configuration file: %s\n", path);
  }

  /* destroy config if already read */
  if (v->config) {
    virgo__conf_destroy(v);
  }

  L = luaL_newstate();
  lua_newtable(L);
  conf_parse(L, fp);
  lua_setglobal(L, "config");

  v->config = calloc(1, sizeof(virgo_conf_t*));
  v->config->L = L;

  fclose(fp);

  return VIRGO_SUCCESS;
}
