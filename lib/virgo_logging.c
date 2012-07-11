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
#include "virgo__types.h"

#include <errno.h>
#include <string.h>
#include <time.h>

#define MAX_LOG_LINE_LENGTH 4000

virgo_error_t*
virgo__log_rotate(virgo_t *v)
{
  FILE *old = v->log_fp;
  FILE *nxt = stderr;

  if (v->log_path != NULL) {
    nxt = fopen(v->log_path, "ab");
    if (nxt == NULL) {
      char buf[256];
      int err = errno;
#ifdef _WIN32
      strncpy(&buf[0], strerror(err), sizeof(buf));
#else
      strerror_r(err, &buf[0], sizeof(buf));
#endif
      logCrit(v, "Failed to open log file: %s (errno=%d,%s)", v->log_path,
              err, &buf[0]);

      return virgo_error_createf(VIRGO_EIO,
                                "Failed to open log file: %s (errno=%d,%s)",
                                v->log_path, err, &buf[0]);
    }
  }

  v->log_fp = nxt;

  if (old != NULL && old != stderr) {
    fclose(old);
  }

  if (v->log_path) {
    virgo_log_infof(v, "Log file started (path=%s)", v->log_path);
  }

  return VIRGO_SUCCESS;
}

void virgo_log_level_set(virgo_t *v, virgo_log_level_e level)
{
  v->log_level = level;
}

virgo_log_level_e virgo_log_level_get(virgo_t *v)
{
  return v->log_level;
}

/* Logs a completely formated string into the current log file.
 * Line must include newline, and is written regardless of the log level.
 */
static void
virgo__log_buf(virgo_t *v, const char *str, size_t len)
{
  if (v->log_fp == NULL) {
    v->log_fp = stderr;
  }
  fwrite(str, 1, strlen(str), v->log_fp);
  fflush(v->log_fp);
}

/* Checks if log level is good enough, then prepends date, level, and appends newline.  */
void
virgo_log(virgo_t *v, virgo_log_level_e level, const char *str)
{
  if (virgo_log_level_get(v) < level) {
    return;
  }
  else {
    time_t t;
    char buf[ MAX_LOG_LINE_LENGTH ] = {0};
    size_t slen = 0;
    size_t blen = 0;
    size_t availlen;
    struct tm tm;
    struct tm *ptm;
    const char *llstr = NULL;

    slen = strlen(str);
    t = time(NULL);

#ifdef _WIN32
    /* modern version of msvc use a thread-local buffer for gmtime_r */
    ptm = gmtime(&t);
    memcpy(&tm, ptm, sizeof(struct tm));
    ptm = &tm;
    {
      char *p = asctime(ptm);
      memcpy(&buf[0], p, 24);
    }
#else
    ptm = gmtime_r(&t, &tm);
    /* TODO: use a different time format ?*/
    asctime_r(ptm, &buf[0]);
#endif

    /* asctime always sets string to a 24 character long time stamp. */
    blen += 24;

    switch (level) {
      case VIRGO_LOG_CRITICAL:
        llstr = " CRT: ";
        break;
      case VIRGO_LOG_ERRORS:
        llstr = " ERR: ";
        break;
      case VIRGO_LOG_WARNINGS:
        llstr = " WRN: ";
        break;
      case VIRGO_LOG_INFO:
        llstr = " INF: ";
        break;
      case VIRGO_LOG_DEBUG:
        llstr = " DBG: ";
        break;
      default:
        llstr = " UNK: ";
        break;
    }

    memcpy(&buf[0]+blen, llstr, 6);
    blen += 6;

    availlen = sizeof(buf) - blen - 2;

    if (slen > availlen) {
      slen = availlen;
    }

    memcpy(&buf[0] + blen, str, slen);
    blen += slen;

    memcpy(&buf[0] + blen, "\n\0", 2);
    blen += 2;

    virgo__log_buf(v, &buf[0], blen);

    /* In the event of a critical message, we also try to log it to stderr, increasing the chance a human sees it. */
    if (level == VIRGO_LOG_CRITICAL &&
        v->log_fp != stderr) {
      fwrite(&buf[0], 1, blen, stderr);
      fflush(stderr);
    }
  }
}

void
virgo_log_fmtv(virgo_t *v, virgo_log_level_e level, const char *fmt, va_list ap)
{
  if (virgo_log_level_get(v) >= level) {
    char buf[MAX_LOG_LINE_LENGTH];
    int rv = vsnprintf(&buf[0], sizeof(buf), fmt, ap);
    if (rv >= 0) {
      /* PQ:TODO: This is not as efficient as it could be, we could build
       * the log line inline here with a little code refactoring, rather than
       * an inline snprintf/calling out to the string based logger.
       */
      virgo_log(v, level, buf);
    }
  }
}

void virgo_log_fmt(virgo_t *v, virgo_log_level_e level, const char* fmt, ...)
{
  va_list ap;

  va_start(ap, fmt);
  virgo_log_fmtv(v, level, fmt, ap);
  va_end(ap);
}

void virgo_log_criticalf(virgo_t *v, const char *fmt, ...)
{
  va_list ap;

  va_start(ap, fmt);
  virgo_log_fmtv(v, VIRGO_LOG_CRITICAL, fmt, ap);
  va_end(ap);
}

void virgo_log_errorf(virgo_t *v, const char *fmt, ...)
{
  va_list ap;

  va_start(ap, fmt);
  virgo_log_fmtv(v, VIRGO_LOG_ERRORS, fmt, ap);
  va_end(ap);
}

void virgo_log_warningf(virgo_t *v, const char *fmt, ...)
{
  va_list ap;

  va_start(ap, fmt);
  virgo_log_fmtv(v, VIRGO_LOG_WARNINGS, fmt, ap);
  va_end(ap);
}

void
virgo_log_infof(virgo_t *v, const char *fmt, ...)
{
  va_list ap;

  va_start(ap, fmt);
  virgo_log_fmtv(v, VIRGO_LOG_INFO, fmt, ap);
  va_end(ap);
}

void
virgo_log_debugf(virgo_t *v, const char *fmt, ...)
{
  va_list ap;

  va_start(ap, fmt);
  virgo_log_fmtv(v, VIRGO_LOG_DEBUG, fmt, ap);
  va_end(ap);
}

void
virgo_log_critical(virgo_t *v, const char *str)
{
  virgo_log(v, VIRGO_LOG_CRITICAL, str);
}

void
virgo_log_error(virgo_t *v, const char *str)
{
  virgo_log(v, VIRGO_LOG_ERRORS, str);
}

void
virgo_log_warning(virgo_t *v, const char *str)
{
  virgo_log(v, VIRGO_LOG_WARNINGS, str);
}

void
virgo_log_info(virgo_t *v, const char *str)
{
  virgo_log(v, VIRGO_LOG_INFO, str);
}

void
virgo_log_debug(virgo_t *v, const char *str)
{
  virgo_log(v, VIRGO_LOG_DEBUG, str);
}
