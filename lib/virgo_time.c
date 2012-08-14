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
#ifdef _WIN32
#include <time.h>
#else
#include <sys/time.h>
#endif

#include <stdio.h>
#include <math.h>
#include "lua.h"
#include "virgo.h"
#include "virgo_portable.h"

#ifdef _WIN32

#include <windows.h>

union timestamp_u {
  FILETIME ft_;
  int64_t t_;
};

#define kTimeEpoc 116444736000000000LL
#define kTimeScaler 10000

static double
virgo__time_now() {
  union timestamp_u ts;
  GetSystemTimeAsFileTime(&ts.ft_);
  return (double)((ts.t_ - kTimeEpoc) / kTimeScaler);
}

#else

static double
virgo__time_now() {
  struct timeval tv;
  if (gettimeofday(&tv, NULL) < 0) {
    return 0.0;
  }
  return (((double)tv.tv_sec * 1000) + ((double)tv.tv_usec / 1000));
}

#endif

int
virgo_time_now(lua_State *L) {
  lua_pushnumber(L, virgo__time_now());
  return 1;
}
