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
#include <stdlib.h>

/* TODO:  move to private headers. */
struct virgo_t {
  int dummy;
};

virgo_error_t*
virgo_create(virgo_t **p_v)
{
  virgo_t *v = NULL;

  v = calloc(1, sizeof(virgo_t));
  *p_v = v;

  return VIRGO_SUCCESS;
}


void 
virgo_destroy(virgo_t *v)
{
  free((void*)v);
}
