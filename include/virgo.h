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

#include "virgo_visibility.h"
#include "virgo_portable.h"
#include "virgo_error.h"

#ifndef _virgo_h_
#define _virgo_h_

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/** Opaque context of a Virgo Instance. */
typedef struct virgo_t virgo_t;

/**
 * Creates a Virgo context.
 */
VIRGO_API(virgo_error_t*) virgo_create(virgo_t **ctxt, const char *default_module);

/**
 * Destroys a Virsgo context. After this call, ctxt points to invalid memory
 * and should not be used.
 */
VIRGO_API(void) virgo_destroy(virgo_t *ctxt);

/**
 * Runs the configured Virgo Context.  Only returns on fatal error, or
 * when tricked into exiting for purposes of a test case.
 */
VIRGO_API(virgo_error_t*) virgo_run(virgo_t *v);

/**
 * Set a trusted CA certificate for Network operations
 */
VIRGO_API(virgo_error_t*) virgo_conf_trust_network_ca(virgo_t *v, const char *ca_cert);

/**
 * Set a trusted CA certificate for Code Valiation.  This should
 * be different than the CA used for Network operations.
 */
VIRGO_API(virgo_error_t*) virgo_conf_trust_code_ca(virgo_t *v, const char *ca_cert);

/**
 * Set path to a Zip file containing Lua files. init.lua inside the zip file
 * will be ran first, and other files can be loaded via require.
 */
VIRGO_API(virgo_error_t*) virgo_conf_lua_load_path(virgo_t *v, const char *path);

/**
 * Set path to a Zip file containing Lua files. init.lua inside the zip file
 * will be ran first, and other files can be loaded via require.
 */
VIRGO_API(virgo_error_t*) virgo_conf_args(virgo_t *v, int argc, char **argv);


#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* _virgo_h_ */
