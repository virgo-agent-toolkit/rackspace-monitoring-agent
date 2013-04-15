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

#ifndef _virgo_exec_h_
#define _virgo_exec_h_

#include "virgo_brand.h"
#include "virgo_visibility.h"
#include "virgo_portable.h"
#include "virgo_error.h"
#include "uv.h"

typedef void(*virgo__exec_upgrade_cb)(virgo_t *v, const char *fmt, ...);

/* Look for a new executable and bundle, then exec them.
 * Note: does not return on success.
 */
VIRGO_API(virgo_error_t*) virgo__exec_upgrade(virgo_t *v,
                                              int *perform_upgrade,
                                              virgo__exec_upgrade_cb status);

/* Check that the exe_path is newer than the current internal exe version */
int virgo__is_new_exe(const char* exe_path, const char* version);

#endif
