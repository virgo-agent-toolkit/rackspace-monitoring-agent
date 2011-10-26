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

#ifndef _virgo__lua_h_
#define _virgo__lua_h_

virgo_error_t* virgo__lua_init(virgo_t *v);
void virgo__lua_destroy(virgo_t *v);

virgo_t* virgo__lua_context(lua_State *L);

void virgo__lua_loader_init(lua_State *L);

int virgo__lua_debugger_init(lua_State *L);

#endif /* _virgo__lua_h_ */
