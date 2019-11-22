REM @ECHO off
@SET LIT_VERSION=3.7.3
@SET LUVI_VERSION=v2.9.3-sigar

IF NOT "x%1" == "x" GOTO :%1

:rackspace-monitoring-agent
ECHO "Building agent"
IF NOT EXIST luvi-sigar.exe CALL Make.bat luvi-sigar
if %errorlevel% neq 0 goto error
IF NOT EXIST lit.exe CALL Make.bat lit
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
reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set ARCH=ia32 || set ARCH=amd64
PowerShell -NoProfile -ExecutionPolicy unrestricted -Command "Invoke-WebRequest -Uri https://github.com/virgo-agent-toolkit/luvi/releases/download/%LUVI_VERSION%/luvi-sigar-Windows-%ARCH%.exe -OutFile luvi-sigar.exe"
if %errorlevel% neq 0 goto error
GOTO :end

:lit
ECHO "Building lit"
IF NOT EXIST luvi-sigar.exe CALL Make.bat luvi-sigar
if %errorlevel% neq 0 goto error
mkdir build
cd build
git clone --recursive https://github.com/luvit/lit.git
if %errorlevel% neq 0 goto error
cd lit
git checkout %LIT_VERSION%
@rem The following runs the lit source via luvi-sigar and calls itself to make the lit source
@rem into ..\..\lit.exe and embedding specifically ..\..\luvi-sigar.exe as its luvi
..\..\luvi-sigar.exe . -- make . ..\..\lit.exe ..\..\luvi-sigar.exe
if %errorlevel% neq 0 goto error
cd ..\..
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

