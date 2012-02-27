#ifndef _virgo__lua_tls_h_
#define _virgo__lua_tls_h_

#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>

/* TLS Connection class info, cross file */

/* SecureContext used to configure multiple connections */
typedef struct tls_sc_t {
  SSL_CTX *ctx;
  /* TODO: figure out CA-store plan */
  X509_STORE *ca_store;
} tls_sc_t;

tls_sc_t* virgo__lua_tls_sc_get(lua_State *L, int index);
int virgo__lua_tls_conn_init(lua_State *L);
int virgo__lua_tls_conn_create(lua_State *L);

#endif
