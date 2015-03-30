cmake_minimum_required(VERSION 2.8.9)

project(rackspace-monitoring-agent NONE)

set(APP_NAME    "rackspace-monitoring-agent")
set(APP_VENDOR  "Rackspace")
set(APP_SUMMARY "Rackspace Monitoring Agent")
set(APP_CONTACT "monitoring@rackspace.com")

set(ENV{LUVI_APP} ".")
set(ENV{LUVI_MAIN} "contrib/printversion.lua")
execute_process(
  COMMAND lit
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  OUTPUT_VARIABLE VERSION_SHORT
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
set(ENV{LUVI_MAIN} "")
set(ENV{LUVI_APP} "")

message("Packaging ${APP_NAME} ${VERSION_SHORT}")

###############################################################################
## Enumerate System
###############################################################################

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")
include (EnumerateSystem)

###############################################################################
## Installation Targets
###############################################################################

set(LICENSE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.txt")
set(CPACK_RESOURCE_FILE_LICENSE ${LICENSE_FILE})
set(PACKAGE_SCRIPTS "${CMAKE_CURRENT_SOURCE_DIR}/cmake/package")
set(GENERATED_PACKAGE_SCRIPTS "${CMAKE_BINARY_DIR}/package")

install(PROGRAMS ${APP_NAME} DESTINATION bin)
install(FILES ${LICENSE_FILE} DESTINATION share/${APP_NAME})

if (${SPECIFIC_SYSTEM_VERSION_NAME} MATCHES "^Linux")
  ### logrotate
  set(LOGROTATE_SCRIPT ${GENERATED_PACKAGE_SCRIPTS}/logrotate/${APP_NAME})
  message("Generating Log Rotate Script ${LOGROTATE_SCRIPT}")
  configure_file(${PACKAGE_SCRIPTS}/logrotate/script.in
                 ${LOGROTATE_SCRIPT})
  install(PROGRAMS ${LOGROTATE_SCRIPT} DESTINATION /etc/logrotate.d)
endif()

###############################################################################
## Packaging
###############################################################################

if (NOT CPACK_SYSTEM_NAME)
  set(CPACK_SYSTEM_NAME "${CMAKE_SYSTEM_PROCESSOR}")
  if (CPACK_SYSTEM_NAME STREQUAL "x86_64")
    set(CPACK_SYSTEM_NAME "amd64")
  endif ()
endif ()

set(CPACK_PACKAGE_NAME ${APP_NAME})
set(CPACK_PACKAGE_VENDOR ${APP_VENDOR})
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY ${APP_SUMMARY})
set(CPACK_PACKAGE_VERSION ${VERSION_SHORT})
set(CPACK_PACKAGE_INSTALL_DIRECTORY ${APP_NAME})
set(CPACK_PACKAGE_CONTACT ${APP_CONTACT})
set(CPACK_GENERATOR ${SPECIFIC_SYSTEM_PREFERED_CPACK_GENERATOR})
set(CPACK_NSIS_MODIFY_PATH ON)

include (CPack)
