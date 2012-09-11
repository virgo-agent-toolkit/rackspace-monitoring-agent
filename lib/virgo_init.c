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
#include "virgo__conf.h"
#include "virgo__types.h"
#include "virgo__lua.h"
#include "virgo__logging.h"
#include "virgo__util.h"
#include "uv.h"
#include "luv.h"
#include <stdlib.h>
#include <assert.h>

#include <openssl/ssl.h>
#include <openssl/evp.h>
#include <openssl/err.h>

/**
 * We hard code a check here for the version of OpenSSL we bundle inside deps, because its
 * too easily to accidently pull in an older version of OpenSSL on random platforms with
 * weird include paths.
 */
#if OPENSSL_VERSION_NUMBER != VIRGO_OPENSSL_VERSION_NUMBER
#error Invalid OpenSSL version number. Busted Include Paths?
#endif

static int global_virgo_init = 0;

#ifndef __linux__

void virgo__crash_reporter_init()
{
  
}

void virgo__crash_reporter_destroy()
{
  
}

#endif

static void
virgo__global_init() {
#if !defined(OPENSSL_NO_COMP)
  STACK_OF(SSL_COMP)* comp_methods;
#endif

  virgo__crash_reporter_init();

  if (global_virgo_init++) {
    return;
  }

  SSL_library_init();
  OpenSSL_add_all_algorithms();
  OpenSSL_add_all_digests();
  SSL_load_error_strings();
  ERR_load_crypto_strings();

  /* Turn off compression. Saves memory - do it in userland. */
#if !defined(OPENSSL_NO_COMP)
#if OPENSSL_VERSION_NUMBER < 0x00908000L
  comp_methods = SSL_COMP_get_compression_method()
#else
  comp_methods = SSL_COMP_get_compression_methods();
#endif
  sk_SSL_COMP_zero(comp_methods);
  assert(sk_SSL_COMP_num(comp_methods) == 0);
#endif

  /* TODO: other platform init */
}

static void
virgo__global_terminate(void)
{
    global_virgo_init--;
    /* TODO: cleanup more */
    if (global_virgo_init == 0) {
      virgo__crash_reporter_destroy();
    }
}

virgo_error_t*
virgo_create(virgo_t **p_v, const char *default_module)
{
  virgo_t *v = NULL;

  virgo__global_init();

  v = calloc(1, sizeof(virgo_t));
  v->lua_default_module = strdup(default_module);
  v->log_level = VIRGO_LOG_EVERYTHING;
  *p_v = v;

  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo_run(virgo_t *v)
{
  virgo_error_t* err;

  if (virgo__argv_has_flag(v, "-h", "--help") == 1) {
    return virgo_error_create(VIRGO_EHELPREQ, "--help was passed");;
  }

  if (virgo__argv_has_flag(v, "-v", "--version") == 1) {
    return virgo_error_create(VIRGO_EVERSIONREQ, "--version was passed");;
  }

#ifdef _WIN32
  if (virgo__argv_has_flag(v, NULL, "--service-install") == 1) {
    return virgo__service_install(v);
  }

  if (virgo__argv_has_flag(v, NULL, "--service-delete") == 1) {
    return virgo__service_delete(v);
  }
#endif

#ifndef _WIN32
  if (virgo__argv_has_flag(v, "-D", "--detach") == 1) {
    err = virgo_detach();
    if (err != VIRGO_SUCCESS) {
      return err;
    }
  }
#endif
  err = virgo__lua_init(v);

  if (err ) {
    return err;
  }

  err = virgo__log_rotate(v);

  if (err) {
    return err;
  }

  err = virgo__conf_init(v);

  if (err) {
    return err;
  }

#ifdef _WIN32
  err = virgo__service_handler(v);
#else
  /* TOOD: restart support */
  err = virgo__lua_run(v);
#endif

  if (err) {
    return err;
  }

  return VIRGO_SUCCESS;
}

uv_loop_t* virgo_get_loop(virgo_t *v) {
  return luv_get_loop(v->L);
}

void
virgo_destroy(virgo_t *v)
{
  virgo__lua_destroy(v);

  if (v->config) {
    virgo__conf_destroy(v);
  }
  if (v->lua_load_path) {
    free((void*)v->lua_load_path);
  }
  if (v->lua_default_module) {
    free((void*)v->lua_default_module);
  }

  if (v->log_path) {
    free((void*)v->log_path);
  }
  if (v->log_fp && v->log_fp != stderr) {
    fclose(v->log_fp);
  }
  if (v->lua_bundle_path) {
    free((void*)v->lua_bundle_path);
  }

  free((void*)v);

  virgo__global_terminate();
}

const char*
virgo_get_load_path(virgo_t *ctxt) {
  return ctxt->lua_load_path;
}
