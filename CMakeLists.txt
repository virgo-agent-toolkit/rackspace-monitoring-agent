cmake_minimum_required(VERSION 2.8.9)

project(rackspace-monitoring-agent NONE)

set(APP_NAME    "rackspace-monitoring-agent")
set(APP_VENDOR  "Rackspace")
set(APP_SUMMARY "Rackspace Monitoring Agent")

set(ENV{LUVI_APP} ".")
set(ENV{LUVI_MAIN} "contrib/printversion.lua")
execute_process(
  COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/lit
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  OUTPUT_VARIABLE VERSION_SHORT
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(ENV{LUVI_MAIN} "")
set(ENV{LUVI_APP} "")

message("Packaging ${APP_NAME} ${VERSION_SHORT}")

option(WithPackageSH "Build shell-installable package." OFF)
option(WithPackageTGZ "Build gziped tarball package." OFF)
option(WithPackageTBZ2 "Build bzip2'd tarball package." OFF)
option(WithPackageDEB "Build DEB package." OFF)
option(WithPackageRPM "Build RPM package." OFF)
option(WithPackageNSIS "Build NSIS package." OFF)
option(WithPackageBUNDLE "Build OSX bundle." OFF)

###############################################################################
## Installation Targets
###############################################################################

set(CPACK_RESOURCE_FILE_LICENSE ${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.txt)

install(PROGRAMS rackspace-monitoring-agent DESTINATION bin)

###############################################################################
## Packaging
###############################################################################

if(WithPackageSH OR WithPackageTGZ OR WithPackageTBZ2 OR WithPackageDEB
   OR WithPackageRPM OR WithPackageNSIS OR WithPackageBUNDLE)

  set(CPACK_PACKAGE_NAME ${APP_NAME})
  set(CPACK_PACKAGE_VENDOR ${APP_VENDOR})
  set(CPACK_PACKAGE_DESCRIPTION_SUMMARY ${APP_SUMMARY})
  set(CPACK_PACKAGE_VERSION ${VERSION_SHORT})
  set(CPACK_PACKAGE_INSTALL_DIRECTORY ${APP_NAME})
  set(CPACK_NSIS_MODIFY_PATH ON)

  unset(PACKAGE_LIST)
  if (WithPackageSH)
    list(APPEND CPACK_GENERATOR "STGZ")
    list(APPEND PACKAGE_LIST "Shell-installable package (.sh)")
  endif ()
  if (WithPackageTGZ)
    list(APPEND CPACK_GENERATOR "TGZ")
    list(APPEND PACKAGE_LIST "gziped tarball (.tar.gz)")
  endif ()
  if (WithPackageTBZ2)
    list(APPEND CPACK_GENERATOR "TBZ2")
    list(APPEND PACKAGE_LIST "bzip2'd tarball (.tar.bz2)")
  endif ()
  if (WithPackageDEB)
    list(APPEND CPACK_GENERATOR "DEB")
    list(APPEND PACKAGE_LIST "DEB package (.deb)")
    set(CPACK_DEBIAN_PACKAGE_SECTION "net")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Luvit Authors")
  endif ()
  if (WithPackageRPM)
    list(APPEND CPACK_GENERATOR "RPM")
    list(APPEND PACKAGE_LIST "RPM package (.rpm)")
    set(CPACK_RPM_PACKAGE_RELEASE 1)
    set(CPACK_RPM_PACKAGE_LICENSE "Apache 2")
  endif ()
  if (WithPackageNSIS)
    list(APPEND CPACK_GENERATOR "NSIS")
    list(APPEND PACKAGE_LIST "NSIS package (.exe)")
  endif ()
  if (WithPackageBUNDLE)
    list(APPEND CPACK_GENERATOR "Bundle")
    list(APPEND PACKAGE_LIST "OSX Bundle (.dmg)")
    set(CPACK_BUNDLE_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/packaging/macosx/Info.plist)
    set(CPACK_BUNDLE_ICON ${CMAKE_CURRENT_SOURCE_DIR}/packaging/macosx/Icons.icns)
    set(CPACK_BUNDLE_NAME "luvi")
  endif ()
  string(REPLACE ";" ", " PACKAGE_LIST "${PACKAGE_LIST}")

  include(CPack)
else()
  set(PACKAGE_LIST "None")
endif()
