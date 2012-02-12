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
#if OPENSSL_VERSION_NUMBER != 0x1000005fL
#error Invalid OpenSSL version number. Busted Include Paths?
#endif


#define TLS_SECURE_CONTEXT_HANDLE "ltls_secure_context"
#define TLS_CONNECTION_HANDLE "ltls_connection"

/* SecureContext used to configure multiple connections */
typedef struct tls_sc_t {
  SSL_CTX *ctx;
  /* TODO: figure out CA-store plan */
  X509_STORE *ca_store;
} tls_sc_t;

/* TLS object that maps to an individual connection */
typedef struct tls_conn_t {
  BIO *bio_read;
  BIO *bio_write;
  SSL *ssl;
  int is_server;
} tls_conn_t;



/**
 * TLS Secure Context Methods
 */

static tls_sc_t*
newSC(lua_State *L)
{
  tls_sc_t* ctx;
  ctx = lua_newuserdata(L, sizeof(tls_sc_t));
  ctx->ctx = NULL;
  /* TODO: reference gloabl CA-store */
  ctx->ca_store = NULL;

  /* TODO: make method configurable */
  ctx->ctx = SSL_CTX_new(TLSv1_method());
  /* TODO: customize Session cache */
  SSL_CTX_set_session_cache_mode(ctx->ctx, SSL_SESS_CACHE_SERVER);

  luaL_getmetatable(L, TLS_SECURE_CONTEXT_HANDLE);
  lua_setmetatable(L, -2);
  return ctx;
}

static tls_sc_t*
getSC(lua_State *L)
{
  tls_sc_t *ctx = luaL_checkudata(L, 1, TLS_SECURE_CONTEXT_HANDLE);
  return ctx;
}

static int
tls_sc_create(lua_State *L) {
  tls_sc_t* ctx;
  ctx = newSC(L);
  return 1;
}

static BIO*
str2bio(const char *value, size_t length) {
  int r;
  BIO *bio;

  bio = BIO_new(BIO_s_mem());

  r = BIO_write(bio, value, length);

  if (r <= 0) {
    BIO_free(bio);
    return NULL;
  }

  return bio;
};

static int
tls_fatal_error_x(lua_State *L, const char *func) {
  char buf[256];
  unsigned long err = ERR_get_error();

  ERR_error_string(err, buf);

  ERR_clear_error();

  luaL_error(L, "%s: %s", func, buf);

  return 0;
}

#define tls_fatal_error(L) tls_fatal_error_x(L, __func__)

static int
tls_sc_set_key(lua_State *L) {
  tls_sc_t *ctx;
  EVP_PKEY* key;
  BIO *bio;
  const char *passpharse = NULL;
  const char *keystr = NULL;
  size_t klen = 0;
  size_t plen = 0;

  ctx = getSC(L);

  keystr = luaL_checklstring(L, 2, &klen);
  passpharse = luaL_optlstring(L, 3, NULL, &plen);

  bio = str2bio(keystr, klen);
  if (!bio) {
    return luaL_error(L, "tls_sc_set_key: Failed to convert Key into a BIO");
  }

  ERR_clear_error();

  /* If the 3rd arg is NULL, the 4th arg is treated as a const char* istead of void* */
  key = PEM_read_bio_PrivateKey(bio, NULL, NULL, (void*)passpharse);

  if (!key) {
    return tls_fatal_error(L);
  }

  SSL_CTX_use_PrivateKey(ctx->ctx, key);
  EVP_PKEY_free(key);
  BIO_free(bio);

  return 0;
}

static int
tls_sc_close(lua_State *L) {
  tls_sc_t *ctx = getSC(L);

  if (ctx->ctx) {
    SSL_CTX_free(ctx->ctx);
    ctx->ctx = NULL;
    ctx->ca_store = NULL;
  }

  return 0;
}

static int
tls_sc_gc(lua_State *L) {
  return tls_sc_close(L);
}


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

static int
tls_conn_create(lua_State *L) {
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

static const luaL_reg tls_sc_lib[] = {
  {"setKey", tls_sc_set_key},
/*
  {"setCert", tls_sc_set_cert},
  {"addCACert", tls_sc_add_ca_cert},
  {"addRootCerts", tls_sc_add_root_certs},
  {"addCRL", tls_sc_add_root_certs},
  {"setCiphers", tls_sc_set_ciphers},
  {"setOptions", tls_sc_set_options},
*/
  {"close", tls_sc_close},
  {"__gc", tls_sc_gc},
  {NULL, NULL}
};

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

static const luaL_reg tls_lib[] = {
  {"secure_context", tls_sc_create},
  {"connection", tls_conn_create},
  {NULL, NULL}
};

int
virgo__lua_tls_init(lua_State *L)
{
  luaL_newmetatable(L, TLS_SECURE_CONTEXT_HANDLE);
  lua_pushliteral(L, "__index");
  lua_pushvalue(L, -2);  /* push metatable */
  lua_rawset(L, -3);  /* metatable.__index = metatable */
  luaL_openlib(L, NULL, tls_sc_lib, 0);
  lua_pushvalue(L, -1);

  luaL_newmetatable(L, TLS_CONNECTION_HANDLE);
  lua_pushliteral(L, "__index");
  lua_pushvalue(L, -2);  /* push metatable */
  lua_rawset(L, -3);  /* metatable.__index = metatable */
  luaL_openlib(L, NULL, tls_conn_lib, 0);
  lua_pushvalue(L, -1);

  luaL_openlib(L, "_tls", tls_lib, 1);
  return 1;
}
