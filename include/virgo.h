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

#include "virgo_brand.h"
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

/** Opaque context of a Virgo Config Instance. */
typedef struct virgo_conf_t virgo_conf_t;

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

/**
 * Get variable from config.
 * @return NULL when key is not found.
 */
VIRGO_API(const char*) virgo_conf_get(virgo_t *v, const char *key);


/**
 * Log levels.
 */
typedef enum
{
  VIRGO_LOG_NOTHING,
  VIRGO_LOG_CRITICAL,
  VIRGO_LOG_ERRORS,
  VIRGO_LOG_WARNINGS,
  VIRGO_LOG_INFO,
  VIRGO_LOG_DEBUG,
  VIRGO_LOG_EVERYTHING
} virgo_log_level_e;

/* Get and set the log level on a context */
VIRGO_API(void) virgo_log_level_set(virgo_t *v, virgo_log_level_e level);
VIRGO_API(virgo_log_level_e) virgo_log_level_get(virgo_t *v);

/* Log a simple string, at the specified log level. */
VIRGO_API(void) virgo_log(virgo_t *v, virgo_log_level_e level, const char *str);

/* Simple variants:
 *    - Prepends Timestamp, log level.
 *    - Appends a newline
 */
VIRGO_API(void) virgo_log_critical(virgo_t *v, const char *str);
VIRGO_API(void) virgo_log_error(virgo_t *v, const char *str);
VIRGO_API(void) virgo_log_warning(virgo_t *v, const char *str);
VIRGO_API(void) virgo_log_info(virgo_t *v, const char *str);
VIRGO_API(void) virgo_log_debug(virgo_t *v, const char *str);

/* Format string variants of the log operations */
VIRGO_API(void)  virgo_log_fmtv(virgo_t *v, virgo_log_level_e level, const char* fmt, va_list ap);
VIRGO_API(void)  virgo_log_fmt(virgo_t *v, virgo_log_level_e level, const char* fmt, ...) VIRGO_ATTR_FMT_FUNC(3,4);
VIRGO_API(void)  virgo_log_criticalf(virgo_t *v, const char *fmt, ...) VIRGO_ATTR_FMT_FUNC(2,3);
VIRGO_API(void)  virgo_log_errorf(virgo_t *v, const char *fmt, ...) VIRGO_ATTR_FMT_FUNC(2,3);
VIRGO_API(void)  virgo_log_warningf(virgo_t *v, const char *fmt, ...) VIRGO_ATTR_FMT_FUNC(2,3);
VIRGO_API(void)  virgo_log_infof(virgo_t *v, const char *fmt, ...) VIRGO_ATTR_FMT_FUNC(2,3);
VIRGO_API(void)  virgo_log_debugf(virgo_t *v, const char *fmt, ...) VIRGO_ATTR_FMT_FUNC(2,3);


#ifndef logCrit
#define logCrit virgo_log_criticalf
#endif

#ifndef logErr
#define logErr virgo_log_errorf
#endif

#ifndef logWarn
#define logWarn virgo_log_warningf
#endif

#ifndef logInfo
#define logInfo virgo_log_infof
#endif

#ifndef logDbg
#define logDbg virgo_log_debugf
#endif

/* Version number of OpenSSL that we hard link into */
#define VIRGO_OPENSSL_VERSION_NUMBER 0x1000005fL

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* _virgo_h_ */
