@ECHO off
@SET LIT_VERSION=1.2.13

IF NOT "x%1" == "x" GOTO :%1

:rackspace-monitoring-agent
ECHO "Building agent"
IF NOT EXIST lit.exe CALL Make.bat lit
CALL cmake -H. -Bbuild
CALL cmake --build build
CALL cmake --build build --target SignExe
GOTO :end

:lit
ECHO "Building lit"
PowerShell -NoProfile -ExecutionPolicy unrestricted -Command "iex ((new-object net.webclient).DownloadString('https://github.com/luvit/lit/raw/%LIT_VERSION%/get-lit.ps1'))"
GOTO :end

:test
CALL Make.bat rackspace-monitoring-agent
CALL lit.exe install
IF EXIST tests\tmpdir RMDIR /S /Q tests\tmpdir
CALL mkdir tests\tmpdir
CALL luvi.exe . -m tests\run.lua
exit /b %errorlevel%
GOTO :end

:package
IF NOT EXIST rackspace-monitoring-agent.exe CALL Make.bat rackspace-monitoring-agent
CALL cmake --build build --target package
CALL cmake --build build --target SignPackage
GOTO :end

:packagerepo
call cmake --build build --target packagerepo
GOTO :end

:packagerepoupload
call cmake --build build --target packagerepoupload
GOTO :end

:clean
IF EXIST rackspace-monitoring-agent.exe DEL /F /Q rackspace-monitoring-agent.exe
IF EXIST lit.exe DEL /F /Q lit.exe
IF EXIST lit RMDIR /S /Q lit
IF EXIST luvi.exe DEL /F /Q luvi.exe
IF EXIST luvi-binaries RMDIR /S /Q luvi-binaries

:end

