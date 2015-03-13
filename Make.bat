@ECHO off

IF NOT "x%1" == "x" GOTO :%1

:rackspace-monitoring-agent
ECHO "Building agent"
IF NOT EXIST lit.exe CALL Make.bat lit
IF NOT EXIST libs\sigar.dll CALL Make.bat sigar
lit.exe make
GOTO :end

:sigar
git clone --recursive https://github.com/virgo-agent-toolkit/lua-sigar
IF NOT EXIST libs CALL mkdir libs
pushd lua-sigar
call cmake -G"Visual Studio 12 Win64" .
call make.bat
copy sigar.dll ..\libs
popd
GOTO :end

:lit
ECHO "Building lit"
PowerShell -NoProfile -ExecutionPolicy unrestricted -Command "iex ((new-object net.webclient).DownloadString('https://github.com/luvit/lit/raw/1.0.0/get-lit.ps1'))"
copy lit.exe luvi.exe
GOTO :end

:test
CALL Make.bat rackspace-monitoring-agent
virgo.exe
GOTO :end

:clean
IF EXIST rackspace-monitoring-agent.exe DEL /F /Q rackspace-monitoring-agent.exe
IF EXIST lit.exe DEL /F /Q lit.exe
IF EXIST lit RMDIR /S /Q lit
IF EXIST luvi.exe DEL /F /Q luvi.exe
IF EXIST luvi-binaries RMDIR /S /Q luvi-binaries

:end


