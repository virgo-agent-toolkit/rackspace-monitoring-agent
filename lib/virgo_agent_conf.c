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
#include "virgo__conf.h"
#include "virgo__util.h"

virgo_error_t*
virgo__agent_conf_init(virgo_t *v)
{
  lua_getglobal(v->L, "virgo");
  lua_pushstring(v->L, "agent_config");
  lua_newtable(v->L);
  lua_settable(v->L, -3);
  lua_remove(v->L, -1);

  return VIRGO_SUCCESS;
}

VIRGO_API(virgo_error_t*)
virgo_agent_conf_set(virgo_t *v, const char *key, const char *val)
{
  lua_getglobal(v->L, "virgo");
  lua_getfield(v->L, -1, "agent_config");
  lua_remove(v->L, -2);

  lua_pushstring(v->L, key);
  lua_pushstring(v->L, val);
  lua_settable(v->L, -3);

  return VIRGO_SUCCESS;
}
