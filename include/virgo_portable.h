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

/**
 * @file virgo_portable.h
 */

#include <stdarg.h>

#ifndef _virgo_portable_h_
#define _virgo_portable_h_

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

#if _WIN32
#define snprintf _snprintf
#define VIRGO_WANT_ASPRINTF
#define vasprintf virgo_vasprintf
#define asprintf virgo_asprintf
#endif


#ifdef VIRGO_WANT_ASPRINTF
#include <stdio.h>
int virgo_vasprintf(char **outstr, const char *fmt, va_list args);
int virgo_asprintf(char **outstr, const char *fmt, ...);
#else

#endif

char* virgo_basename(char *name);

/* Function annotation attribute to declare a function takes a format string, 
 * and to check it for valid args.
 */
#if !defined(SWIG) && !defined(_MSC_VER)
#define VIRGO_ATTR_FMT_FUNC(x,y) __attribute__((format(printf,x,y)));
#else
#define VIRGO_ATTR_FMT_FUNC(x,y)
#endif

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif
