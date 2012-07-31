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
#include "virgo_error.h"
#include "virgo__types.h"
#include "virgo__conf.h"
#include "virgo__util.h"

#include <assert.h>
#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#ifndef _WIN32
#include <unistd.h>
#include <errno.h>
#endif

virgo_error_t*
virgo_conf_service_name(virgo_t *v, const char *name)
{
  if (v->service_name) {
    free((void*)v->service_name);
  }

  v->service_name = strdup(name);

  return VIRGO_SUCCESS;
}

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
  virgo_error_t *err;
  const char *arg;

  v->argc = argc;
  v->argv = argv;

  arg = virgo__argv_get_value(v, "-z", "--zip");
  if (arg != NULL) {
    err = virgo_conf_lua_load_path(v, arg);
    if (err) {
      return err;
    }
  }

  arg = virgo__argv_get_value(v, "-l", "--logfile");
  if (arg != NULL) {
    v->log_path = strdup(arg);
  }

  return VIRGO_SUCCESS;
}

const char*
virgo_conf_get(virgo_t *v, const char *key)
{
  return virgo__conf_get(v, key);
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
conf_insert_node_to_table(virgo_t *v, const char *key, const char *value)
{
  lua_pushstring(v->L, key);
  lua_pushstring(v->L, value);
  lua_settable(v->L, -3);
}

static void
conf_parse(virgo_t *v, FILE *fp)
{
  char buf[8096];
  char *p = NULL;
  while ((p = fgets(buf, sizeof(buf), fp)) != NULL) {
    char *key;
    virgo_conf_t *node;

    /* comment lines */
    if (p[0] == '#') {
      continue;
    }

    while (isspace(p[0])) { p++;};

    if (strlen(p) == 0) {
      continue;
    }

    /* Insert into list */
    node = calloc(1, sizeof(*node));
    node->next = v->config;
    v->config = node;

    /* calculate key/value pairs */
    key = next_chunk(&p);
    p = key;
    while(!isspace(p[0])) { p++;};
    *p = '\0'; /* null terminate key */
    node->key = strdup(key);
    p++;
    while(isspace(p[0])) { p++;};
    node->value = strdup(p);

    free(key);
    conf_insert_node_to_table(v, node->key, node->value);
  }
}

const char*
virgo__conf_get(virgo_t *v, const char *key)
{
  virgo_conf_t *p = v->config;

  if (strcmp("lua_load_path", key) == 0) {
    return v->lua_load_path;
  }

  while (p) {
    if (strcmp(p->key, key) == 0) {
      return p->value;
    }
    p = p->next;
  }
  return NULL;
}

void
virgo__conf_destroy(virgo_t *v)
{
  virgo_conf_t *p = v->config, *t;
  while (p) {
    t = p->next;
    free((void*)p->key);
    free((void*)p->value);
    free(p);
    p = t;
  }
  v->config = NULL;
}

static virgo_error_t*
virgo__conf_get_path(virgo_t *v, const char **p_path)
{
#ifdef _WIN32
  char *programfiles;
  const char *path;

  path = virgo__argv_get_value(v, "-c", "--config");

  if (path == NULL) {
    char gen_path[512];
    programfiles = getenv("ProgramFiles");

    if (programfiles == NULL) {
      return virgo_error_create(VIRGO_EINVAL, "Unable to get environment variable: \"ProgramFiles\"\n");
    }

    sprintf(gen_path, "%s\\%s\\etc\\",
            programfiles,
            VIRGO_DEFAULT_CONFIG_WINDOWS_DIRECTORY,
            VIRGO_DEFAULT_CONFIG_FILENAME);

    *p_path = strdup(gen_path);

    return VIRGO_SUCCESS;
  }

  *p_path = strdup(path);

  return VIRGO_SUCCESS;
#else /* !_WIN32 */
  const char *path;

  path = virgo__argv_get_value(v, "-c", "--config");

  if (path == NULL) {
    *p_path = strdup(VIRGO_DEFAULT_CONFIG_UNIX_PATH);
    return VIRGO_SUCCESS;
  }

  *p_path = strdup(path);
  return VIRGO_SUCCESS;
#endif
}


virgo_error_t*
virgo__conf_init(virgo_t *v)
{
  virgo_error_t* err;
  FILE *fp;
  const char *path;

  err = virgo__conf_get_path(v, &path);

  if (err) {
    return err;
  }

  /* destroy config if already read */
  if (v->config) {
    virgo__conf_destroy(v);
  }

  /* put config in virgo.config table */
  fp = fopen(path, "r");
  if (fp) {
    lua_getglobal(v->L, "virgo");
    lua_pushstring(v->L, "config");
    lua_newtable(v->L);
    conf_parse(v, fp);
    lua_settable(v->L, -3);
    fclose(fp);
  }

  lua_pushstring(v->L, "config_path");
  lua_pushstring(v->L, path);
  lua_settable(v->L, -3);

  free((void*)path);

  return VIRGO_SUCCESS;
}
