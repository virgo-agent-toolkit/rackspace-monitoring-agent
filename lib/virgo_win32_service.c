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
#include "virgo__types.h"
#include "virgo_error.h"
#include "virgo_paths.h"

#ifdef _WIN32

#include <windows.h>
#include <process.h>
#include <stdlib.h>

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
  schService = OpenService(schSCManager, v->service_name, SC_MANAGER_CONNECT);

  if (schService != NULL) {
    /* service already is installed */
    CloseServiceHandle(schService);
    CloseServiceHandle(schSCManager);
    return VIRGO_SUCCESS;
  }

  schService = CreateService(
      schSCManager,              // SCM database
      v->service_name,                   // name of service
      v->service_name,                   // service name to display
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

  schService = OpenService(schSCManager, v->service_name, DELETE);
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

virgo_error_t*
virgo__service_upgrade(virgo_t *v)
{
  virgo_error_t *err = VIRGO_SUCCESS;
  char origin[VIRGO_PATH_MAX];
  char dest[VIRGO_PATH_MAX];
  SC_HANDLE schSCManager = NULL;
  SC_HANDLE schService = NULL;
  SERVICE_STATUS ServiceStatus;

  schSCManager = OpenSCManager(NULL, NULL, SC_MANAGER_ALL_ACCESS);

  if (NULL == schSCManager) {
    return virgo_error_os_create(VIRGO_EINVAL, GetLastError(), "OpenSCManager failed");
  }

  schService = OpenService(schSCManager, v->service_name, SERVICE_ALL_ACCESS);
  if (schService == NULL) {
    err = virgo_error_os_create(VIRGO_EINVAL, GetLastError(), "OpenService failed");
    goto service_upgrade_end;
  }

  /* Stop the Service that spawned me */
  if (ControlService(schService, SERVICE_CONTROL_STOP, &ServiceStatus)) {
    while (ServiceStatus.dwCurrentState != SERVICE_STOPPED) {
      virgo_log_infof(v, "Waiting for Win32 Service to Stop for Upgrade");
      Sleep(1000);
      if (!QueryServiceStatus(schService, &ServiceStatus)) {
        err = virgo_error_os_create(VIRGO_EINVAL, GetLastError(), "QueryServiceStatus failed");
        goto service_upgrade_end;
      }
    }
  } else {
    err = virgo_error_os_create(VIRGO_EINVAL, GetLastError(), "ControlService failed");
    goto service_upgrade_end;
  }

  /* Copy this service exe and bundle (which should be new) into place */
  /* EXE */
  err = virgo__paths_get(v, VIRGO_PATH_CURRENT_EXECUTABLE_PATH, origin, VIRGO_PATH_MAX);
  if (err != VIRGO_SUCCESS) {
    goto service_upgrade_end;
  }
  err = virgo__paths_get(v, VIRGO_PATH_DEFAULT_EXE, dest, VIRGO_PATH_MAX);
  if (err != VIRGO_SUCCESS) {
    goto service_upgrade_end;
  }
  if (!CopyFile(origin, dest, FALSE)) {
    err = virgo_error_os_create(VIRGO_EINVAL, GetLastError(), "Copy Exe During Upgrade failed");
    goto service_upgrade_end;
  }
  /* Bundle */
  err = virgo__paths_get(v, VIRGO_PATH_DEFAULT_BUNDLE, dest, VIRGO_PATH_MAX);
  if (err != VIRGO_SUCCESS) {
    goto service_upgrade_end;
  }
  if (!CopyFile(v->lua_load_path, dest, FALSE)) {
    err = virgo_error_os_create(VIRGO_EINVAL, GetLastError(), "Copy Bundle During Upgrade failed");
    goto service_upgrade_end;
  }

  /* Start the new service */
  if (!StartService(schService, 0, NULL)) {
    err = virgo_error_os_create(VIRGO_EINVAL, GetLastError(), "StartService failed");
    goto service_upgrade_end;
  }

service_upgrade_end:
  CloseServiceHandle(schService);
  CloseServiceHandle(schSCManager);
  return err;
}

struct baton
{
  virgo_t *v;
  virgo_error_t* (*wrapper)(virgo_t *v);
};
static struct baton virgo_baton_hack = {NULL, NULL};

static VOID WINAPI virgo__win32_service_handler(DWORD dwControl)
{
  virgo_t *v = virgo_baton_hack.v;

  if (dwControl == SERVICE_CONTROL_STOP) {
    v->service_status.dwCurrentState = SERVICE_STOP_PENDING;
    SetEvent(v->service_stop_event);
  }
  SetServiceStatus(v->service_handle, &v->service_status);
}

DWORD WINAPI virgo__win32_service_worker(PVOID baton)
{
  virgo_error_t *err;
  struct baton *virgo_baton = (struct baton *)baton;
  err = virgo_baton->wrapper(virgo_baton->v);
  if (err != VIRGO_SUCCESS) {
    /* TODO: logging? better error handling? */
    virgo_log_errorf(virgo_baton->v, "Win32 Service wrapper error %s:%u %s", err->file, err->line, err->msg);
    return 1;
  }
  return 0;
}

#ifndef ARRAYSIZE
#define ARRAYSIZE(a) sizeof(a)/sizeof(a[0])
#endif

static VOID WINAPI virgo__win32_service_main(DWORD dwArgc,LPTSTR* lpszArgv)
{
  HANDLE worker_thread;
  virgo_t *v = virgo_baton_hack.v;
  v->service_handle = RegisterServiceCtrlHandler(v->service_name, virgo__win32_service_handler);

  if (v->service_handle == NULL) {
    goto error;
  }

  v->service_status.dwCurrentState = SERVICE_RUNNING;
  v->service_status.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
  v->service_status.dwControlsAccepted = SERVICE_ACCEPT_STOP;

  v->service_stop_event = CreateEvent(NULL, TRUE, FALSE, NULL);
  SetServiceStatus(v->service_handle, &v->service_status);

  worker_thread = CreateThread(0, 0, virgo__win32_service_worker, v, 0, NULL);
  if (worker_thread == NULL) {
    goto error;
  }

  {
    HANDLE wait_objects[] = {worker_thread, v->service_stop_event};

    DWORD dwWait = WaitForMultipleObjects(ARRAYSIZE(wait_objects), wait_objects, FALSE, INFINITE);
    if (dwWait == WAIT_OBJECT_0) {
      /* if the thread ended, use the exit code */
      GetExitCodeThread(worker_thread, &v->service_status.dwServiceSpecificExitCode);
    }
  }

  if (v->service_status.dwServiceSpecificExitCode != 0) {
    /* TODO: log */
    v->service_status.dwWin32ExitCode = ERROR_SERVICE_SPECIFIC_ERROR;
  }

  v->service_status.dwCurrentState = SERVICE_STOPPED;
  SetServiceStatus(v->service_handle, &v->service_status);
  return;
error:
  v->service_status.dwWin32ExitCode = GetLastError();
  v->service_status.dwCurrentState = SERVICE_STOPPED;
  SetServiceStatus(v->service_handle, &v->service_status);
}

virgo_error_t*
virgo__service_handler(virgo_t *v, virgo_error_t* (*wrapper)(virgo_t *v))
{
  virgo_error_t *err;

  SERVICE_TABLE_ENTRY ste[]={
    { v->service_name, virgo__win32_service_main },
    { NULL, NULL }
  };

  /* Services are invoked in their own thread, but we aren't allowed to actually
   * pass anything to them. sigh.
   */
  virgo_baton_hack.v = v;
  virgo_baton_hack.wrapper = wrapper;

  if (!StartServiceCtrlDispatcher(ste)) {
    DWORD error = GetLastError();
    if (error == ERROR_FAILED_SERVICE_CONTROLLER_CONNECT) {
      /* This was not staqrted by the Service Manager, so run normally */
      virgo_log_infof(v, "Win32 Service Running Outside the Service Manger");
      err = wrapper(v);
    } else {
      virgo_log_errorf(v, "Win32 Service Failed to Start (%u)", error);
      err = virgo_error_os_create(VIRGO_EINVAL, error, "StartServiceCtrlDispatcher failed");
    }
  } else {
    virgo_log_infof(v, "Win32 Service Started");
    err = VIRGO_SUCCESS;
  }

  return err;
}

#endif
