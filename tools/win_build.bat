if "%1" == "" set BUILD=Debug
if NOT "%1" == "" set BUILD=%1
call "C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\vcvarsall.bat" amd64
devenv.com /build %BUILD% monitoring-agent.sln /project monitoring-agent.vcxproj
