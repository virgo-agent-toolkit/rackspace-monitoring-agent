@ECHO off

IF NOT "x%1" == "x" GOTO :%1

:rackspace-monitoring-agent
ECHO "Building agent"
IF NOT EXIST lit.exe CALL Make.bat lit
IF NOT EXIST binary_modules/sigar.dll CALL make.bat sigar
lit.exe make
GOTO :end

:sigar
ECHO "Building Sigar"
IF NOT EXIST lua-sigar git clone https://github.com/virgo-agent-toolkit/lua-sigar
pushd lua-sigar
call make.bat
popd
IF NOT EXIST binary_modules mkdir binary_modules
COPY lua-sigar\build\Release\sigar.dll binary_modules
GOTO :end

:lit
ECHO "Building lit"
@powershell -NoProfile -ExecutionPolicy unrestricted -Command "iex ((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/luvit/lit/a1bef9c234cf2569ded3b5c7516277c0f5746f70/web-install.ps1'))"

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

