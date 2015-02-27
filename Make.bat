@ECHO off

IF NOT "x%1" == "x" GOTO :%1

:rackspace-monitoring-agent
ECHO "Building agent"
IF NOT EXIST lit.exe CALL Make.bat lit
IF NOT EXIST sigar.dll CALL Make.bat sigar
lit.exe make
GOTO :end

:sigar
git clone --recursive https://github.com/virgo-agent-toolkit/lua-sigar
pushd lua-sigar
call cmake .
call make.bat
copy sigar.dll ..
GOTO :end

:lit
ECHO "Building lit"
@powershell -NoProfile -ExecutionPolicy unrestricted -Command "https://github.com/luvit/lit/raw/0.10.4/get-lit.ps1"
GOTO :end

:test
CALL Make.bat rackspace-monitoring-agent
virgo.exe
GOTO :end

:clean
IF EXIST rackspace-monitoring-agent.exe DEL /F /Q rackspace-monitoring-agent.exe
IF EXIST lit.exe DEL /F /Q lit.exe
IF EXIST lit RMDIR /S /Q lit
IF EXIST luvi-binaries RMDIR /S /Q luvi-binaries

:end
