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
#include "virgo__types.h"
#include "virgo__lua.h"
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
#if OPENSSL_VERSION_NUMBER != 0x1000005fL
#error Invalid OpenSSL version number. Busted Include Paths?
#endif

static int global_virgo_init = 0;

static void
virgo__global_init() {
#if !defined(OPENSSL_NO_COMP)
  STACK_OF(SSL_COMP)* comp_methods;
#endif

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
    /* TODO: cleanup */
}

virgo_error_t*
virgo_create(virgo_t **p_v)
{
  virgo_t *v = NULL;

  virgo__global_init();

  v = calloc(1, sizeof(virgo_t));
  *p_v = v;

  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo_run(virgo_t *v)
{
  virgo_error_t* err;

  err = virgo__lua_init(v);

  return VIRGO_SUCCESS;
}

void
virgo_destroy(virgo_t *v)
{
  virgo__lua_destroy(v);
  free((void*)v);

  virgo__global_terminate();
}
