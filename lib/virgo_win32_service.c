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
#include "virgo__util.h"
#include "virgo__lua.h"

#ifdef _WIN32

#include <windows.h>
#include <process.h>
#include <stdlib.h>

virgo_error_t*
virgo__service_install(virgo_t *v)
{
  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__service_delete(virgo_t *v)
{
  return VIRGO_SUCCESS;
}

static virgo_error_t*
virgo__win32_is_service(int *result)
{
  int rc = 0;
  int err;
  int rv;
  unsigned int i;
  int myPid;
  char *buf = NULL;
  ULONG bufneeded = 0;
  ULONG svccount = 0;
  ULONG resume = 0;
  SC_HANDLE scm;
  ENUM_SERVICE_STATUS_PROCESS* svcPtr;

  *result = -1;

  myPid = _getpid();

  scm = OpenSCManager(0, SERVICES_ACTIVE_DATABASE, SC_MANAGER_ENUMERATE_SERVICE);

  if (scm == NULL) {
    err = GetLastError();
    return virgo_error_createf(VIRGO_EINVAL, "Failed to call OpenSCManager(): %d", err);
  }
  
  rv = EnumServicesStatusExA(scm, SC_ENUM_PROCESS_INFO, SERVICE_WIN32, SERVICE_ACTIVE,
                            NULL, 0,
                            &bufneeded, &svccount,
                            &resume, NULL);

  if (rv == 0) {
    err = GetLastError();
    if (err == ERROR_MORE_DATA) {
      buf = malloc(bufneeded);
    }
    else {
      return virgo_error_createf(VIRGO_EINVAL, "First call to EnumServicesStatusEx() failed: %d", err);
    }
  }
  else {
    return virgo_error_create(VIRGO_EINVAL, "Unexpected success of EnumServicesStatusEx()");
  }

  rv = EnumServicesStatusExA(scm, SC_ENUM_PROCESS_INFO, SERVICE_WIN32, SERVICE_ACTIVE,
                            buf, bufneeded,
                            &bufneeded, &svccount,
                            &resume, NULL);

  if (rv == 0) {
    err = GetLastError();
    return virgo_error_createf(VIRGO_EINVAL, "Second call to EnumServicesStatusEx() failed: %d", err);
  }

  svcPtr = (ENUM_SERVICE_STATUS_PROCESS*) buf;
  for (i = 0; i < svccount; i++, svcPtr++) {
    if (svcPtr->ServiceStatusProcess.dwProcessId == myPid) {
      rc = 1;
      break;
    }
  }

  free(buf);

  *result = rc;

  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__service_handler(virgo_t *v)
{
  virgo_error_t *err;
  int is_service = 0;

  err = virgo__win32_is_service(&is_service);

  if (is_service == 0) {
    err = virgo__lua_run(v);
  }
  else {
    /* TODO: service management. */
  }

  return err;
}

#endif
