--[[
Copyright 2015 Rackspace

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local jsonStringify = require('json').stringify
local logging = require('logging')
local los = require('los')
local table = require('table')
local uv = require('uv')

if los.type() ~= 'win32' then return end

local winsvc = require('winsvc')
local winsvcaux = require('winsvcaux')

local function ReportSvcStatus(svcStatusHandle, svcStatus, dwCurrentState, dwWin32ExitCode, dwWaitHint)
  local dwCheckPoint = 1

  -- Fill in the SERVICE_STATUS structure.

  svcStatus.dwCurrentState = dwCurrentState
  svcStatus.dwWin32ExitCode = dwWin32ExitCode
  svcStatus.dwWaitHint = dwWaitHint

  if dwCurrentState == winsvc.SERVICE_START_PENDING then
    svcStatus.dwControlsAccepted = 0
  else
    svcStatus.dwControlsAccepted = winsvc.SERVICE_ACCEPT_STOP
  end

  if dwCurrentState == winsvc.SERVICE_RUNNING or
    dwCurrentState == winsvc.SERVICE_STOPPED then
    svcStatus.dwCheckPoint = 0
  else
    dwCheckPoint = dwCheckPoint + 1
    svcStatus.dwCheckPoint = dwCheckPoint
  end

  logging.infof('Report Service Status, %s', jsonStringify(svcStatus))
  -- Report the status of the service to the SCM.
  winsvc.SetServiceStatus(svcStatusHandle, svcStatus)
end


exports.SvcInstall = function(svcName, longName, desc, params)
  local svcPath, err = winsvcaux.GetModuleFileName()
  local schService, schSCManager
  local _
  if svcPath == nil then
    logging.errorf('Cannot install service, service path unobtainable, %s', winsvcaux.GetErrorString(err))
    return
  end

  if params and params.args then
    svcPath = svcPath .. ' ' .. table.concat(params.args, ' ')
  end

  -- Get a handle to the SCM database
  schSCManager, err = winsvc.OpenSCManager(nil, nil, winsvc.SC_MANAGER_ALL_ACCESS)
  if schSCManager == nil then
    logging.errorf('OpenSCManager failed, %s', winsvcaux.GetErrorString(err))
    return
  end

  -- Create the Service
  schService, _, err = winsvc.CreateService(
    schSCManager,
    svcName,
    longName,
    winsvc.SERVICE_ALL_ACCESS,
    winsvc.SERVICE_WIN32_OWN_PROCESS,
    winsvc.SERVICE_DEMAND_START,
    winsvc.SERVICE_ERROR_NORMAL,
    svcPath,
    nil,
    nil,
    nil,
    nil)

  if schService == nil then
    logging.errorf('CreateService failed, %s', winsvcaux.GetErrorString(err))
    winsvc.CloseServiceHandle(schSCManager)
    return
  end

  -- Describe the service
  winsvc.ChangeServiceConfig2(schService, winsvc.SERVICE_CONFIG_DESCRIPTION, {lpDescription = desc})
  -- Set the service to restart on failure in 60 seconds
  winsvc.ChangeServiceConfig2(schService, winsvc.SERVICE_CONFIG_FAILURE_ACTIONS,
    {dwResetPeriod = 0, lpsaActions = {
      {Delay = 60000, Type = winsvc.SC_ACTION_RESTART}
    }})

  logging.info('Service installed successfully')

  winsvc.CloseServiceHandle(schService)
  winsvc.CloseServiceHandle(schSCManager)

end


exports.SvcDelete = function(svcname)
  -- Get a handle to the SCM database
  local schSCManager, err = winsvc.OpenSCManager(nil, nil, winsvc.SC_MANAGER_ALL_ACCESS)
  if schSCManager == nil then
    logging.errorf('OpenSCManager failed, %s', winsvcaux.GetErrorString(err))
    return
  end

  local schService, delsuccess

  -- Open the Service
  schService, err = winsvc.OpenService(
    schSCManager,
    svcname,
    winsvc.DELETE)

  if schService == nil then
    logging.errorf('OpenService failed, %s', winsvcaux.GetErrorString(err))
    winsvc.CloseServiceHandle(schSCManager)
    return
  end

  delsuccess, err = winsvc.DeleteService(schService)
  if not delsuccess then
    logging.errorf('DeleteService failed, %s', winsvcaux.GetErrorString(err))
  else
    logging.info('DeleteService succeeded')
  end

  winsvc.CloseServiceHandle(schService)
  winsvc.CloseServiceHandle(schSCManager)

end



exports.SvcStart = function(svcname)
  -- Get a handle to the SCM database
  local schSCManager, err = winsvc.OpenSCManager(nil, nil, winsvc.SC_MANAGER_ALL_ACCESS)
  if schSCManager == nil then
    logging.errorf('OpenSCManager failed, %s', winsvcaux.GetErrorString(err))
    return
  end

  local schService, startsuccess

  -- Open the Service
  schService, err = winsvc.OpenService(
    schSCManager,
    svcname,
    winsvc.SERVICE_START)

  if schService == nil then
    logging.errorf('OpenService failed, %s', winsvcaux.GetErrorString(err))
    winsvc.CloseServiceHandle(schSCManager)
    return
  end

  startsuccess, err = winsvc.StartService(schService, nil)
  if not startsuccess then
    logging.errorf('StartService failed, %s', winsvcaux.GetErrorString(err))
  else
    logging.info('StartService succeeded')
  end

  winsvc.CloseServiceHandle(schService)
  winsvc.CloseServiceHandle(schSCManager)

end



exports.SvcStop = function(svcname)
  -- Get a handle to the SCM database
  local schSCManager, err = winsvc.OpenSCManager(nil, nil, winsvc.SC_MANAGER_ALL_ACCESS)
  if schSCManager == nil then
    logging.errorf('OpenSCManager failed, %s', winsvcaux.GetErrorString(err))
    return
  end

  local schService, success, status

  -- Open the Service
  schService, err = winsvc.OpenService(
    schSCManager,
    svcname,
    winsvc.SERVICE_STOP)

  if schService == nil then
    logging.errorf('OpenService failed, %s', winsvcaux.GetErrorString(err))
    winsvc.CloseServiceHandle(schSCManager)
    return
  end

  -- Stop the Service
  success, status, err = winsvc.ControlService(schService, winsvc.SERVICE_CONTROL_STOP, nil)
  if not success then
    logging.errorf('ControlService stop failed, %s', winsvcaux.GetErrorString(err))
  else
    logging.infof('ControlService stop succeeded, status: %s', jsonStringify(status))
  end

  winsvc.CloseServiceHandle(schService)
  winsvc.CloseServiceHandle(schSCManager)
end


exports.tryRunAsService = function(svcname, runfunc)
  local running = true
  local svcStatusHandle
  local svcStatus = {}

  local function SvcHandler(dwControl, dwEventType, lpEventData, lpContext)
    -- Handle the requested control code. 

    if dwControl == winsvc.SERVICE_CONTROL_STOP then 
      ReportSvcStatus(svcStatusHandle, svcStatus, winsvc.SERVICE_STOP_PENDING, winsvc.NO_ERROR, 0)

      -- Signal the service to stop.
      running = false
      ReportSvcStatus(svcStatusHandle, svcStatus, svcStatus.dwCurrentState, winsvc.NO_ERROR, 0)
         
      return winsvc.NO_ERROR
    elseif dwControl == winsvc.SERVICE_CONTROL_INTERROGATE then 
      return winsvc.NO_ERROR
    else
      return winsvc.ERROR_CALL_NOT_IMPLEMENTED
    end
  end

  local function SvcMain(args, context)
    svcStatusHandle = winsvc.GetStatusHandleFromContext(context)
    -- These SERVICE_STATUS members remain as set here

    svcStatus.dwServiceType = winsvc.SERVICE_WIN32_OWN_PROCESS
    svcStatus.dwServiceSpecificExitCode = 0

    -- Report initial status to the SCM
    ReportSvcStatus(svcStatusHandle, svcStatus, winsvc.SERVICE_START_PENDING, winsvc.NO_ERROR, 15000)

    -- Setup Service Work To Be done
    runfunc()

    -- Report runnings
    ReportSvcStatus(svcStatusHandle, svcStatus, winsvc.SERVICE_RUNNING, winsvc.NO_ERROR, 0)

    -- Wait to end  
    local timer = uv.new_timer()
    uv.timer_start(timer, 0, 2000, function()
      if running then
        uv.timer_again(timer)
      else
        uv.timer_stop(timer)
        uv.close(timer)
        ReportSvcStatus(svcStatusHandle, svcStatus, winsvc.SERVICE_STOPPED, winsvc.NO_ERROR, 0);
        winsvc.EndService(context)
      end
    end)
  end


  local DispatchTable = {}
  DispatchTable[svcname] = { SvcMain, SvcHandler };

  local ret, err = winsvc.SpawnServiceCtrlDispatcher(DispatchTable, function(success, err)
    if success then
      logging.info('Service Control Dispatcher returned after threads exited ok')
      process:exit(0)
    else
      logging.infof('Service Control Dispatcher returned with err, %s', winsvcaux.GetErrorString(err))
      logging.info('Running outside service manager')
      runfunc()
    end
  end, function(err)
    logging.errorf('A Service function returned with err %s', err)
    process:exit(1)
  end)

  if ret then
    logging.info('SpawnServiceCtrlDispatcher Succeeded')
  else
    logging.errorf('SpawnServiceCtrlDispatcher Failed, %s', winsvcaux.GetErrorString(err))
  end
end
