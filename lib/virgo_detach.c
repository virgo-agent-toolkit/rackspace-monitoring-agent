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

/*
 * This file is heavily inspired by the APR function apr_proc_detach which is
 * licensed under the following license:
 *
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#include "virgo.h"
#include "virgo_error.h"

static virgo_error_t*
virgo_shutdown_stdio()
{
  /* close out the standard file descriptors */
  if (freopen("/dev/null", "r", stdin) == NULL) {
    return virgo_error_create(errno, "Failed freopen stdin");
    /* continue anyhow -- note we can't close out descriptor 0 because we
     * have nothing to replace it with, and if we didn't have a descriptor
     * 0 the next file would be created with that value ... leading to
     * havoc.
     */
  }
  if (freopen("/dev/null", "w", stdout) == NULL) {
    return virgo_error_create(errno, "Failed freopen stdout");
  }
   /* We are going to reopen this again in a little while to the error
    * log file, but better to do it twice and suffer a small performance
    * hit for consistancy than not reopen it here.
    */
  if (freopen("/dev/null", "w", stderr) == NULL) {
    return virgo_error_create(errno, "Failed freopen stderr");
  }

  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo_detach()
{
  int x;

  if (chdir("/") == -1) {
    return virgo_error_create(errno, "Failed chdir()");
  }

  x = fork(); 

  if (x > 0) {
    exit(0);
  }
  else if (x == -1) {
    perror("fork");
    fprintf(stderr, "unable to fork new process\n");
    exit(1);  /* we can't do anything here, so just exit. */
  }
  /* RAISE_SIGSTOP(DETACH); */

  /* A setsid() failure is not fatal if we didn't just fork().
   * The calling process may be the process group leader, in
   * which case setsid() will fail with EPERM.
   */
  if (setsid() == -1) {
    return virgo_error_create(errno, "Failed setsid()");
  }

  return virgo_shutdown_stdio();
}
