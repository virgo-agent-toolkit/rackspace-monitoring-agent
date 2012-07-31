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

/* Based off of ETL's error types (which is based off of Subversion's) */

/**
 * @file virgo_error.h
 */

#include <stdint.h>
#include "virgo_visibility.h"

#ifndef _virgo_error_h_
#define _virgo_error_h_

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/**
 * Check if the @c virgo_error_t returned by @a expression is equal to
 * @c VIRGO_SUCCESS.  If it is, do nothing, if not, then return it.
 */
#define VIRGO_ERR(expression) do {                      \
          virgo_error_t *virgo__xx__err = (expression);  \
          if (virgo__xx__err)                           \
            return virgo__xx__err;                      \
        } while (0)

/** A low level error code. */
typedef int virgo_status_t;

/** Successful return value for a function that returns @c virgo_error_t. */
#define VIRGO_SUCCESS NULL

/** The available buffer space was exhausted. */
#define VIRGO_ENOSPACE -1

/** The input was invalid. */
#define VIRGO_EINVAL   -2

/** The requested functionality has not been implemented. */
#define VIRGO_ENOTIMPL -3

/** The I/O operation in question failed. */
#define VIRGO_EIO -4

/* Unable to allocate memory */
#define VIRGO_ENOMEM -5

/* Program usage was requested */
#define VIRGO_EHELPREQ -6

/* Program version was requested */
#define VIRGO_EVERSIONREQ -7

/** An exception object. */
typedef struct {
  /** The underlying status code. */
  virgo_status_t err;

  /** A human readable error message. */
  const char *msg;

  /** The line on which the error occurred. */
  uint32_t line;

  /** The file in which the error occurred. */
  const char *file;
} virgo_error_t;

/**
 * Return a new @c virgo_error_t with underlying @c virgo_status_t @a err
 * and message @a msg.
 */
#define virgo_error_create(err, msg) virgo_error_create_impl(err, 0, 0,    \
                                                           msg,        \
                                                           __LINE__,   \
                                                           __FILE__)

#define virgo_error_os_create(err, oserr, msg) virgo_error_create_impl(err, oserr, 0,    \
                                                           msg,        \
                                                           __LINE__,   \
                                                           __FILE__)


/**
* The underlying function that implements @c virgo_error_t_error_create.
 *
 * This is an implementation detail, and should not be directly called
 * by users.
 */
VIRGO_API(virgo_error_t *)
virgo_error_create_impl(virgo_status_t err,
                        int os_error,
                        int copy_msg,
                        const char *msg,
                        uint32_t line,
                        const char *file);

/**
 * Return a new @c virgo_error_t with underlying @c virgo_status_t @a err
 * and message created @c printf style with @a fmt and varargs.
 */
#define virgo_error_createf(err, fmt, ...) virgo_error_createf_impl(err, 0,    \
                                                                  __LINE__,    \
                                                                  __FILE__,    \
                                                                  fmt,         \
                                                                  __VA_ARGS__)

#define virgo_error_os_createf(err, oserr, fmt, ...) virgo_error_createf_impl(err, oserr,    \
                                                                  __LINE__,    \
                                                                  __FILE__,    \
                                                                  fmt,         \
                                                                  __VA_ARGS__)

/**
 * The underlying function that implements @c virgo_error_createf.
 *
 * This is an implementation detail, and should not be directly called
 * by users.
 */
VIRGO_API(virgo_error_t *)
virgo_error_createf_impl(virgo_status_t err,
                         int os_error,
                         uint32_t line,
                         const char *file,
                         const char *fmt,
                         ...);

/** Destroy @a err. */
VIRGO_API(void)
virgo_error_clear(virgo_error_t *err);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif
