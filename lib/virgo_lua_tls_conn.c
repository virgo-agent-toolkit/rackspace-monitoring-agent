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
#include "virgo__lua.h"

#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>

/**
 * This module is hevily inspired by Node.js' node_crypto.cc:
 *   <https://github.com/joyent/node/blob/master/src/node_crypto.cc>
 */

/**
 * We hard code a check here for the version of OpenSSL we bundle inside deps, because its
 * too easily to accidently pull in an older version of OpenSSL on random platforms with
 * weird include paths.
 */
#if OPENSSL_VERSION_NUMBER != VIRGO_OPENSSL_VERSION_NUMBER
#error Invalid OpenSSL version number. Busted Include Paths?
#endif

#define TLS_CONNECTION_HANDLE "ltls_connection"

/* TLS object that maps to an individual connection */
typedef struct tls_conn_t {
  BIO *bio_read;
  BIO *bio_write;
  SSL *ssl;
  int is_server;
} tls_conn_t;


/**
 * TLS Connection Methods
 */

static tls_conn_t*
newCONN(lua_State *L)
{
  tls_conn_t* tc;
  tc = lua_newuserdata(L, sizeof(tls_conn_t));
  tc->bio_read = NULL;
  tc->bio_write = NULL;
  tc->ssl = NULL;
  luaL_getmetatable(L, TLS_CONNECTION_HANDLE);
  lua_setmetatable(L, -2);
  return tc;
}

static tls_conn_t*
getCONN(lua_State *L)
{
  tls_conn_t *tc = luaL_checkudata(L, 1, TLS_CONNECTION_HANDLE);
  return tc;
}

int
virgo__lua_tls_conn_create(lua_State *L) {
  tls_conn_t* tc = newCONN(L);
  return 1;
}


static int
tls_conn_close(lua_State *L) {
  tls_conn_t *tc = getCONN(L);

  if (tc->ssl) {
    SSL_free(tc->ssl);
    tc->ssl = NULL;
  }

  return 0;
}

static int
tls_conn_gc(lua_State *L) {
  return tls_conn_close(L);
}

static const luaL_reg tls_conn_lib[] = {
/*
  {"encIn", tls_conn_enc_in},
  {"encOut", tls_conn_enc_out},
  {"encPending", tls_conn_enc_pending},
  {"clearOut", tls_conn_clear_out},
  {"clearIn", tls_conn_clear_in},
  {"clearPending", tls_conn_clear_pending},
  {"getPeerCertificate", tls_conn_get_peer_certificate},
  {"getSession", tls_conn_get_session},
  {"setSession", tls_conn_set_session},
  {"getCurrentCipher", tls_conn_get_current_cipher},
  {"shutdown", tls_conn_shutdown},
  {"start", tls_conn_start},
*/
  {"close", tls_conn_close},
  {"__gc", tls_conn_gc},
  {NULL, NULL}
};

int
virgo__lua_tls_conn_init(lua_State *L)
{
  luaL_newmetatable(L, TLS_CONNECTION_HANDLE);
  lua_pushliteral(L, "__index");
  lua_pushvalue(L, -2);  /* push metatable */
  lua_rawset(L, -3);  /* metatable.__index = metatable */
  luaL_openlib(L, NULL, tls_conn_lib, 0);
  lua_pushvalue(L, -1);
  return 0;
}
