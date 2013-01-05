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

#ifndef _virgo__util_h_
#define _virgo__util_h_

void virgo__crash_reporter_init(virgo_t **v);
void virgo__crash_reporter_destroy();
void virgo__force_dump();

const char* virgo__argv_get_value(virgo_t *v,
                            const char *short_opt,
                            const char *long_opt);

int virgo__argv_has_flag(virgo_t *v,
                         const char *short_opt,
                         const char *long_opt);

#ifdef _WIN32

virgo_error_t* virgo__service_install(virgo_t *v);
virgo_error_t* virgo__service_delete(virgo_t *v);
virgo_error_t* virgo__service_handler(virgo_t *v);

#endif

#endif
