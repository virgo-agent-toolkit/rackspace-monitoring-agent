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
#include "virgo__tls.h"


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

#define TLS_SECURE_CONTEXT_HANDLE "ltls_secure_context"
#define getSC(L) virgo__lua_tls_sc_get(L, 1)

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
  luaL_getmetatable(L, TLS_SECURE_CONTEXT_HANDLE);
  lua_setmetatable(L, -2);
  return ctx;
}

tls_sc_t*
virgo__lua_tls_sc_get(lua_State *L, int index)
{
  tls_sc_t *ctx = luaL_checkudata(L, index, TLS_SECURE_CONTEXT_HANDLE);
  return ctx;
}

static int
tls_sc_create(lua_State *L) {
  tls_sc_t* ctx;
  ctx = newSC(L);

  /* TODO: make method configurable */
  ctx->ctx = SSL_CTX_new(TLSv1_method());
  /* TODO: customize Session cache */
  SSL_CTX_set_session_cache_mode(ctx->ctx, SSL_SESS_CACHE_SERVER);

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

  if (err == 0) {
    luaL_error(L, "%s: unknown fatal error", func);
  }
  else {
    ERR_error_string(err, buf);

    ERR_clear_error();

    luaL_error(L, "%s: %s", func, buf);
  }

  return 0;
}

#define tls_fatal_error(L) tls_fatal_error_x(L, __FUNCTION__)

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

/**
 * Read a file that contains our certificate in "PEM" format,
 * possibly followed by a sequence of CA certificates that should be
 * sent to the peer in the Certificate message.
 *
 * Taken from OpenSSL & Node.js - editted for style.
 */
static int
SSL_CTX_use_certificate_chain(SSL_CTX *ctx, BIO *in) {
  int ret = 0;
  X509 *x = NULL;

  x = PEM_read_bio_X509_AUX(in, NULL, NULL, NULL);

  if (x == NULL) {
    SSLerr(SSL_F_SSL_CTX_USE_CERTIFICATE_CHAIN_FILE, ERR_R_PEM_LIB);
    goto end;
  }

  ret = SSL_CTX_use_certificate(ctx, x);

  if (ERR_peek_error() != 0) {
    /* Key/certificate mismatch doesn't imply ret==0 ... */
    ret = 0;
  }

  if (ret) {
    /* If we could set up our certificate, now proceed to the CA certificates. */
    X509 *ca;
    int r;
    unsigned long err;

    if (ctx->extra_certs != NULL) {
      sk_X509_pop_free(ctx->extra_certs, X509_free);
      ctx->extra_certs = NULL;
    }

    while ((ca = PEM_read_bio_X509(in, NULL, NULL, NULL))) {
      r = SSL_CTX_add_extra_chain_cert(ctx, ca);

      if (!r) {
        X509_free(ca);
        ret = 0;
        goto end;
      }
      /* Note that we must not free r if it was successfully
       * added to the chain (while we must free the main
       * certificate, since its reference count is increased
       * by SSL_CTX_use_certificate). */
    }

    /* When the while loop ends, it's usually just EOF. */
    err = ERR_peek_last_error();
    if (ERR_GET_LIB(err) == ERR_LIB_PEM &&
        ERR_GET_REASON(err) == PEM_R_NO_START_LINE) {
      ERR_clear_error();
    } else  {
      /* some real error */
      ret = 0;
    }
  }

end:
  if (x != NULL) {
    X509_free(x);
  }
  return ret;
}

/**
 * Read from a BIO, adding to the x509 store.
 */
static int
X509_STORE_load_bio(X509_STORE *ca_store, BIO *in) {
  int ret = 1;
  X509 *ca;
  int r;
  int found = 0;
  unsigned long err;

  while ((ca = PEM_read_bio_X509(in, NULL, NULL, NULL))) {

    r = X509_STORE_add_cert(ca_store, ca);

    if (r == 0) {
      X509_free(ca);
      ret = 0;
      break;
    }

    found++;

    /**
     * The x509 cert object is reference counted by OpenSSL, so the STORE
     * keeps it alive after its been added.
     */
    X509_free(ca);
  }

  /* When the while loop ends, it's usually just EOF. */
  err = ERR_peek_last_error();
  if (found != 0 &&
      ERR_GET_LIB(err) == ERR_LIB_PEM &&
      ERR_GET_REASON(err) == PEM_R_NO_START_LINE) {
    ERR_clear_error();
  } else  {
    /* some real error */
    ret = 0;
  }

  return ret;
}

static int
tls_sc_set_cert(lua_State *L) {
  tls_sc_t *ctx;
  BIO *bio;
  const char *keystr = NULL;
  size_t klen = 0;
  int rv;

  ctx = getSC(L);

  keystr = luaL_checklstring(L, 2, &klen);

  bio = str2bio(keystr, klen);
  if (!bio) {
    return luaL_error(L, "tls_sc_set_key: Failed to convert Cert into a BIO");
  }

  ERR_clear_error();

  rv = SSL_CTX_use_certificate_chain(ctx->ctx, bio);

  if (!rv) {
    BIO_free(bio);
    return tls_fatal_error(L);
  }

  BIO_free(bio);

  return 0;
}

static int
tls_sc_add_trusted_cert(lua_State *L) {
  tls_sc_t *ctx;
  BIO *bio;
  const char *certstr = NULL;
  size_t clen = 0;
  int rv;

  ctx = getSC(L);

  if (ctx->ca_store == NULL) {
    /* TODO: better handling of global CA cert list */
    ctx->ca_store = X509_STORE_new();
    SSL_CTX_set_cert_store(ctx->ctx, ctx->ca_store);
  }

  certstr = luaL_checklstring(L, 2, &clen);

  bio = str2bio(certstr, clen);

  if (!bio) {
    return luaL_error(L, "tls_sc_add_trusted_cert: Failed to convert Cert into a BIO");
  }

  ERR_clear_error();

  rv = X509_STORE_load_bio(ctx->ca_store, bio);

  if (!rv) {
    BIO_free(bio);
    return tls_fatal_error(L);
  }

  BIO_free(bio);

  return 0;
}

static int
tls_sc_set_ciphers(lua_State *L) {
  tls_sc_t *ctx;
  const char *cipherstr = NULL;
  size_t clen = 0;
  int rv;

  ctx = getSC(L);

  cipherstr = luaL_checklstring(L, 2, &clen);

  ERR_clear_error();

  rv = SSL_CTX_set_cipher_list(ctx->ctx, cipherstr);

  if (rv == 0) {
    return tls_fatal_error(L);
  }

  return 0;
}

static int
tls_sc_set_options(lua_State *L) {
  tls_sc_t *ctx;
  uint64_t opts = 0;

  ctx = getSC(L);

  opts = luaL_checknumber(L, 2);

  SSL_CTX_set_options(ctx->ctx, opts);

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



static const luaL_reg tls_sc_lib[] = {
  {"setKey", tls_sc_set_key},
  {"setCert", tls_sc_set_cert},
  {"setCiphers", tls_sc_set_ciphers},
  {"setOptions", tls_sc_set_options},
  {"addTrustedCert", tls_sc_add_trusted_cert},
/*
  {"addRootCerts", tls_sc_add_root_certs},
  {"addCRL", tls_sc_add_root_certs},
*/
  {"close", tls_sc_close},
  {"__gc", tls_sc_gc},
  {NULL, NULL}
};

static const luaL_reg tls_lib[] = {
  {"secure_context", tls_sc_create},
  {"connection", virgo__lua_tls_conn_create},
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

  virgo__lua_tls_conn_init(L);

  luaL_openlib(L, "_tls", tls_lib, 1);

#ifdef SSL_OP_ALL
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_ALL);
#endif

#ifdef SSL_OP_ALLOW_UNSAFE_LEGACY_RENEGOTIATION
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_ALLOW_UNSAFE_LEGACY_RENEGOTIATION);
#endif

#ifdef SSL_OP_CIPHER_SERVER_PREFERENCE
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_CIPHER_SERVER_PREFERENCE);
#endif

#ifdef SSL_OP_CISCO_ANYCONNECT
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_CISCO_ANYCONNECT);
#endif

#ifdef SSL_OP_COOKIE_EXCHANGE
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_COOKIE_EXCHANGE);
#endif

#ifdef SSL_OP_CRYPTOPRO_TLSEXT_BUG
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_CRYPTOPRO_TLSEXT_BUG);
#endif

#ifdef SSL_OP_DONT_INSERT_EMPTY_FRAGMENTS
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_DONT_INSERT_EMPTY_FRAGMENTS);
#endif

#ifdef SSL_OP_EPHEMERAL_RSA
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_EPHEMERAL_RSA);
#endif

#ifdef SSL_OP_LEGACY_SERVER_CONNECT
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_LEGACY_SERVER_CONNECT);
#endif

#ifdef SSL_OP_MICROSOFT_BIG_SSLV3_BUFFER
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_MICROSOFT_BIG_SSLV3_BUFFER);
#endif

#ifdef SSL_OP_MICROSOFT_SESS_ID_BUG
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_MICROSOFT_SESS_ID_BUG);
#endif

#ifdef SSL_OP_MSIE_SSLV2_RSA_PADDING
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_MSIE_SSLV2_RSA_PADDING);
#endif

#ifdef SSL_OP_NETSCAPE_CA_DN_BUG
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_NETSCAPE_CA_DN_BUG);
#endif

#ifdef SSL_OP_NETSCAPE_CHALLENGE_BUG
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_NETSCAPE_CHALLENGE_BUG);
#endif

#ifdef SSL_OP_NETSCAPE_DEMO_CIPHER_CHANGE_BUG
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_NETSCAPE_DEMO_CIPHER_CHANGE_BUG);
#endif

#ifdef SSL_OP_NETSCAPE_REUSE_CIPHER_CHANGE_BUG
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_NETSCAPE_REUSE_CIPHER_CHANGE_BUG);
#endif

#ifdef SSL_OP_NO_COMPRESSION
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_NO_COMPRESSION);
#endif

#ifdef SSL_OP_NO_QUERY_MTU
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_NO_QUERY_MTU);
#endif

#ifdef SSL_OP_NO_SESSION_RESUMPTION_ON_RENEGOTIATION
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_NO_SESSION_RESUMPTION_ON_RENEGOTIATION);
#endif

#ifdef SSL_OP_NO_SSLv2
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_NO_SSLv2);
#endif

#ifdef SSL_OP_NO_SSLv3
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_NO_SSLv3);
#endif

#ifdef SSL_OP_NO_TICKET
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_NO_TICKET);
#endif

#ifdef SSL_OP_NO_TLSv1
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_NO_TLSv1);
#endif

#ifdef SSL_OP_NO_TLSv1_1
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_NO_TLSv1_1);
#endif

#ifdef SSL_OP_NO_TLSv1_2
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_NO_TLSv1_2);
#endif

#ifdef SSL_OP_PKCS1_CHECK_1
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_PKCS1_CHECK_1);
#endif

#ifdef SSL_OP_PKCS1_CHECK_2
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_PKCS1_CHECK_2);
#endif

#ifdef SSL_OP_SINGLE_DH_USE
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_SINGLE_DH_USE);
#endif

#ifdef SSL_OP_SINGLE_ECDH_USE
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_SINGLE_ECDH_USE);
#endif

#ifdef SSL_OP_SSLEAY_080_CLIENT_DH_BUG
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_SSLEAY_080_CLIENT_DH_BUG);
#endif

#ifdef SSL_OP_SSLREF2_REUSE_CERT_TYPE_BUG
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_SSLREF2_REUSE_CERT_TYPE_BUG);
#endif

#ifdef SSL_OP_TLS_BLOCK_PADDING_BUG
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_TLS_BLOCK_PADDING_BUG);
#endif

#ifdef SSL_OP_TLS_D5_BUG
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_TLS_D5_BUG);
#endif

#ifdef SSL_OP_TLS_ROLLBACK_BUG
  VIRGO_DEFINE_CONSTANT(L, SSL_OP_TLS_ROLLBACK_BUG);
#endif

  return 1;
}
