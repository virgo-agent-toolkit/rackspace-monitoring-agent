REM @ECHO off
@SET LIT_VERSION=3.5.4

IF NOT "x%1" == "x" GOTO :%1

:rackspace-monitoring-agent
ECHO "Building agent"
IF NOT EXIST lit.exe CALL Make.bat lit
if %errorlevel% neq 0 goto error
IF NOT EXIST luvi-sigar.exe CALL Make.bat luvi-sigar
if %errorlevel% neq 0 goto error
IF NOT "x%CMAKE_GENERATOR%" == "x" (
  CALL cmake -H. -Bbuild -G "%CMAKE_GENERATOR%"
) ELSE (
  CALL cmake -H. -Bbuild
)
if %errorlevel% neq 0 goto error
CALL cmake --build build
if %errorlevel% neq 0 goto error
CALL cmake --build build --target SignExe
if %errorlevel% neq 0 goto error
GOTO :end

:luvi-sigar
ECHO "Fetching Luvi Sigar"
CALL lit.exe get-luvi -o luvi-sigar.exe
if %errorlevel% neq 0 goto error
GOTO :end

:lit
ECHO "Building lit"
PowerShell -NoProfile -ExecutionPolicy unrestricted -Command "iex ((new-object net.webclient).DownloadString('https://github.com/luvit/lit/raw/%LIT_VERSION%/get-lit.ps1'))"
if %errorlevel% neq 0 goto error
GOTO :end

:test
CALL Make.bat rackspace-monitoring-agent
if %errorlevel% neq 0 goto error
CALL lit.exe install
if %errorlevel% neq 0 goto error
IF EXIST tests\tmpdir RMDIR /S /Q tests\tmpdir
CALL mkdir tests\tmpdir
CALL luvi-sigar.exe . -m tests\run.lua
if %errorlevel% neq 0 goto error
GOTO :end

:package
IF NOT EXIST rackspace-monitoring-agent.exe CALL Make.bat rackspace-monitoring-agent
CALL cmake --build build --target package
if %errorlevel% neq 0 goto error
CALL cmake --build build --target SignPackage
if %errorlevel% neq 0 goto error
GOTO :end

:packageupload
call cmake --build build --target packageupload
if %errorlevel% neq 0 goto error
GOTO :end

:clean
IF EXIST rackspace-monitoring-agent.exe DEL /F /Q rackspace-monitoring-agent.exe
IF EXIST lit.exe DEL /F /Q lit.exe
IF EXIST lit RMDIR /S /Q lit
IF EXIST luvi.exe DEL /F /Q luvi.exe
IF EXIST luvi-sigar.exe DEL /F /Q luvi-sigar.exe
IF EXIST luvi-binaries RMDIR /S /Q luvi-binaries
GOTO :end

:error
exit /b %errorlevel%

:end

