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

/* TODO: Make part of agent config? */
#define SVCNAME "Rackspace Monitoring Agent"

virgo_error_t*
virgo__service_install(virgo_t *v)
{
  int rv;
  char exePath[MAX_PATH];
  SC_HANDLE schSCManager;
  SC_HANDLE schService;
  LPTSTR szDesc = TEXT("Provides Rackspace Monitoring Agent. The agent can record disk, bandwidth, CPU usage, and more. Data collected from the agent goes into Rackspace Cloud Monitoring's systems.");
  SERVICE_DESCRIPTION sd;
  SC_ACTION sa[1];
  SERVICE_FAILURE_ACTIONS sfa;

  if (!GetModuleFileNameA(NULL, exePath, MAX_PATH)) {
    return virgo_error_os_create(VIRGO_EINVAL, GetLastError(), "Cannot get module file name.");
  }

  schSCManager = OpenSCManager(NULL, NULL, SC_MANAGER_ALL_ACCESS);

  if (NULL == schSCManager) {
    return virgo_error_os_create(VIRGO_EINVAL, GetLastError(), "OpenSCManager failed");
  }

  /* Check if already installed... */
  schService = OpenService(schSCManager, SVCNAME, SC_MANAGER_CONNECT);

  if (schService != NULL) {
    /* service already is installed */
    CloseServiceHandle(schService);
    CloseServiceHandle(schSCManager);
    return VIRGO_SUCCESS;
  }

  schService = CreateService(
      schSCManager,              // SCM database
      SVCNAME,                   // name of service
      SVCNAME,                   // service name to display
      SERVICE_ALL_ACCESS,        // desired access
      SERVICE_WIN32_OWN_PROCESS, // service type
      SERVICE_AUTO_START,        // start type
      SERVICE_ERROR_NORMAL,      // error control type
      exePath,                    // path to service's binary
      NULL,                      // no load ordering group
      NULL,                      // no tag identifier
      NULL,                      // no dependencies
      NULL,                      // LocalSystem account
      NULL);                     // no password

  if (schService == NULL) {
    CloseServiceHandle(schSCManager);
    return virgo_error_createf(VIRGO_EINVAL, "CreateService failed: err=%d", GetLastError());
  }


  sd.lpDescription = szDesc;

  rv = ChangeServiceConfig2(schService, SERVICE_CONFIG_DESCRIPTION, &sd);

  if (rv == 0) {
    CloseServiceHandle(schService);
    CloseServiceHandle(schSCManager);
    return virgo_error_createf(VIRGO_EINVAL, "ChangeServiceConfig2 SERVICE_CONFIG_DESCRIPTION failed: err=%d", GetLastError());
  }

  sfa.dwResetPeriod = 0;
  sfa.lpRebootMsg = NULL;
  sfa.lpCommand = NULL;
  sfa.cActions = 1;
  sa[0].Type = SC_ACTION_RESTART;
  sa[0].Delay = 0;
  sfa.lpsaActions = sa;
  sfa.dwResetPeriod = 0;

  rv = ChangeServiceConfig2(schService, SERVICE_CONFIG_FAILURE_ACTIONS, &sfa);

  if (rv == 0) {
    CloseServiceHandle(schService);
    CloseServiceHandle(schSCManager);
    return virgo_error_createf(VIRGO_EINVAL, "ChangeServiceConfig2 SERVICE_CONFIG_FAILURE_ACTIONS failed: err=%d", GetLastError());
  }

  CloseServiceHandle(schService);
  CloseServiceHandle(schSCManager);

  return VIRGO_SUCCESS;
}

virgo_error_t*
virgo__service_delete(virgo_t *v)
{
  virgo_error_t *err;
  SC_HANDLE schSCManager;
  SC_HANDLE schService;
  schSCManager = OpenSCManager(NULL, NULL, SC_MANAGER_ALL_ACCESS);

  if (NULL == schSCManager) {
    return virgo_error_os_create(VIRGO_EINVAL, GetLastError(), "OpenSCManager failed");
  }

  schService = OpenService(schSCManager, SVCNAME, DELETE);
  if (schService == NULL) {
    err = virgo_error_os_create(VIRGO_EINVAL, GetLastError(), "OpenService failed");
    CloseServiceHandle(schSCManager);
    return err;
  }

  // Delete the service.
  if (!DeleteService(schService)) {
    err = virgo_error_os_create(VIRGO_EINVAL, GetLastError(), "DeleteService failed");
  }

  CloseServiceHandle(schService);
  CloseServiceHandle(schSCManager);
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
