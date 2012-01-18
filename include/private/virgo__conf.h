#include "virgo.h"

#ifndef _virgo__conf_h_
#define _virgo__conf_h_

virgo_error_t* virgo__conf_init(virgo_t *v);
const char* virgo__conf_get(virgo_t *v, const char *key);
void virgo__conf_destroy(virgo_t *v);

#endif
