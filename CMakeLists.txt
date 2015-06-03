cmake_minimum_required(VERSION 2.8.9)

project(rackspace-monitoring-agent NONE)

message("CMAKE_GENERATOR: ${CMAKE_GENERATOR}")

set(APP_NAME    "rackspace-monitoring-agent")
set(APP_VENDOR  "Rackspace")
set(APP_CREATOR "${APP_VENDOR} Monitoring")
set(APP_SUMMARY "${APP_CREATOR} Agent")
set(APP_CONTACT "monitoring@rackspace.com")
set(APP_DESCRIPTION ${APP_SUMMARY})

if (DEFINED ENV{FORCE_REPO_NAME})
  set(FORCE_REPO_NAME $ENV{FORCE_REPO_NAME})
endif()

if (DEFINED ENV{FORCE_VERSION})
  set(FORCE_VERSION $ENV{FORCE_VERSION})
endif()

if (WIN32)
  set(APP_NAME_INSTALL  "${APP_NAME}.exe")
else()
  set(APP_NAME_INSTALL  "${APP_NAME}")
endif()

if (${FORCE_VERSION} MATCHES "^[0-9]+.[0-9]+.[0-9]+$")
  FILE(READ ${CMAKE_CURRENT_SOURCE_DIR}/package.lua FILE_CONTENT)
  STRING(REGEX REPLACE "version = \"[0-9]+.[0-9]+.[0-9]+\"" "version = \"${FORCE_VERSION}\""
    MODIFIED_FILE_CONTENT "${FILE_CONTENT}")
  FILE(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/package.lua "${MODIFIED_FILE_CONTENT}")
endif()  

include(ExternalProject)

execute_process(
  COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/luvi contrib/printversion
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  OUTPUT_VARIABLE VERSION_SHORT
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

file(GLOB_RECURSE LUA_FILES "*.lua")
add_custom_command(
  OUTPUT ${APP_NAME_INSTALL}
  DEPENDS ${LUA_FILES}
  COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/lit make ..
)
add_custom_target(agent ALL DEPENDS ${APP_NAME_INSTALL})

message("Packaging ${APP_NAME} ${VERSION_SHORT}")
###############################################################################
## Enumerate System
###############################################################################

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")
include(EnumerateSystem)

###############################################################################
## Installation Targets
###############################################################################

set(LICENSE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.txt")
set(CPACK_RESOURCE_FILE_LICENSE ${LICENSE_FILE})
set(PACKAGE_SCRIPTS "${CMAKE_CURRENT_SOURCE_DIR}/cmake/package")
set(GENERATED_PACKAGE_SCRIPTS "${CMAKE_BINARY_DIR}/package")
set(REPOSITORY_SCRIPTS "${CMAKE_CURRENT_SOURCE_DIR}/cmake/repo")
set(GENERATED_REPOSITORY_SCRIPTS "${CMAKE_BINARY_DIR}/repo")

set(REPO_RPM_NAME "cloudmonitoring")
set(REPO_UPLOAD_CLOUD "rackspace")
set(SIGNATURE_KEY "~/server.key")

if (${SPECIFIC_SYSTEM_VERSION_NAME} MATCHES "^Linux")
  install(PROGRAMS ${CMAKE_BINARY_DIR}/${APP_NAME_INSTALL} DESTINATION bin)
  install(FILES ${LICENSE_FILE} DESTINATION share/${APP_NAME})

  ### logrotate
  set(LOGROTATE_SCRIPT ${GENERATED_PACKAGE_SCRIPTS}/logrotate/${APP_NAME})
  message("Generating Log Rotate Script ${LOGROTATE_SCRIPT}")
  configure_file(${PACKAGE_SCRIPTS}/logrotate/script.in ${LOGROTATE_SCRIPT})
  install(PROGRAMS ${LOGROTATE_SCRIPT} DESTINATION /etc/logrotate.d)

  if (${SPECIFIC_SYSTEM_PREFERED_CPACK_GENERATOR} MATCHES "RPM")
    ### systemd init script
    set(SYSTEMD_SCRIPT ${GENERATED_PACKAGE_SCRIPTS}/systemd/${APP_NAME}.service)
    message("Generating systemd script ${SYSTEMD_SCRIPT}")
    configure_file(${PACKAGE_SCRIPTS}/systemd/service.in ${SYSTEMD_SCRIPT})
    install(FILES ${SYSTEMD_SCRIPT} DESTINATION /etc/systemd/system)

    ### SysV Init Script
    set(SYSV_SCRIPT ${GENERATED_PACKAGE_SCRIPTS}/sysv-redhat/${APP_NAME})
    message("Generating sysv-redhat script ${SYSV_SCRIPT}")
    configure_file(${PACKAGE_SCRIPTS}/sysv-redhat/script.in ${SYSV_SCRIPT})
    install(PROGRAMS ${SYSV_SCRIPT} DESTINATION /etc/init.d)

    ### RPM Post Install
    set(RPM_POSTINST ${GENERATED_PACKAGE_SCRIPTS}/rpm/postinst)
    message("Generating script ${RPM_POSTINST}")
    configure_file(${PACKAGE_SCRIPTS}/rpm/postinst.in ${RPM_POSTINST})
    set(CPACK_RPM_POST_INSTALL_SCRIPT_FILE ${RPM_POSTINST})

    ### RPM Pre UnInstall
    set(RPM_PREUN ${GENERATED_PACKAGE_SCRIPTS}/rpm/preun)
    message("Generating script ${RPM_PREUN}")
    configure_file(${PACKAGE_SCRIPTS}/rpm/preun.in ${RPM_PREUN})
    set(CPACK_RPM_PRE_UNINSTALL_SCRIPT_FILE ${RPM_PREUN})

    set(CPACK_RPM_EXCLUDE_FROM_AUTO_FILELIST
      /usr
      /usr/bin
      /usr/share
      /etc
      /etc/logrotate.d
      /etc/systemd
      /etc/systemd/system
      /etc/init.d
    )

    ### Do not Strip RPM
    set(CPACK_RPM_SPEC_INSTALL_POST "/bin/true")

    include(CreateRepo)
  elseif(${SPECIFIC_SYSTEM_PREFERED_CPACK_GENERATOR} MATCHES "DEB")
    ### Control Files
    set(DEB_POSTRM ${GENERATED_PACKAGE_SCRIPTS}/debian/postrm)
    configure_file(${PACKAGE_SCRIPTS}/debian/postrm.in ${DEB_POSTRM})
    set(DEB_POSTINST ${GENERATED_PACKAGE_SCRIPTS}/debian/postinst)
    configure_file(${PACKAGE_SCRIPTS}/debian/postinst.in ${DEB_POSTINST})
    set(DEB_PRERM ${GENERATED_PACKAGE_SCRIPTS}/debian/prerm)
    configure_file(${PACKAGE_SCRIPTS}/debian/postinst.in ${DEB_PRERM})
    set(CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA "${DEB_POSTRM};${DEB_POSTINST};${DEB_PRERM}")

    ### systemd init script
    set(SYSTEMD_SCRIPT ${GENERATED_PACKAGE_SCRIPTS}/systemd/${APP_NAME}.service)
    message("Generating systemd script ${SYSTEMD_SCRIPT}")
    configure_file(${PACKAGE_SCRIPTS}/systemd/service.in ${SYSTEMD_SCRIPT})
    install(FILES ${SYSTEMD_SCRIPT} DESTINATION /etc/systemd/system)

    ### SysV
    set(DEB_SYSV ${GENERATED_PACKAGE_SCRIPTS}/debian/${APP_NAME})
    configure_file(${PACKAGE_SCRIPTS}/debian/service.init.in ${DEB_SYSV})
    install(PROGRAMS ${DEB_SYSV} DESTINATION /etc/init.d)

    ### Upstart
    set(DEB_UPSTART ${GENERATED_PACKAGE_SCRIPTS}/debian/${APP_NAME}.conf)
    configure_file(${PACKAGE_SCRIPTS}/debian/service.upstart.in ${DEB_UPSTART})
    install(FILES ${DEB_UPSTART} DESTINATION /etc/init)

    include(RepRepro)
  endif()
  include(Sign)
endif()

if (WIN32)
  if ("${CMAKE_GENERATOR}" MATCHES "Win64")
    set(CPACK_WIX_SIZEOF_VOID_P 8)
    set(PFILESDIR "ProgramFiles64Folder")
  else()
    set(CPACK_WIX_SIZEOF_VOID_P 4)
    set(PFILESDIR "ProgramFilesFolder")
  endif()
  set(CPACK_WIX_EXTENSIONS WixUtilExtension)
  set(CPACK_WIX_TEMPLATE "${PACKAGE_SCRIPTS}/windows/virgo.wxs")
  set(PRODUCTEXE ${CMAKE_BINARY_DIR}/${APP_NAME_INSTALL})
  set(APP_ICO "${CMAKE_CURRENT_SOURCE_DIR}/agent.ico")
  set(LONG_DESCRIPTION "Rackspace Monitoring Agent Service")
endif()

###############################################################################
## Packaging
###############################################################################

if (NOT CPACK_SYSTEM_NAME)
  if (WIN32)
    if ("${CMAKE_GENERATOR}" MATCHES "Win64")
      set(CPACK_SYSTEM_NAME x64)
    else()
      set(CPACK_SYSTEM_NAME ia32)
    endif()
  else(WIN32)
    set(CPACK_SYSTEM_NAME "${CMAKE_SYSTEM_PROCESSOR}")
	if (CPACK_SYSTEM_NAME STREQUAL "x86_64")
	  set(CPACK_SYSTEM_NAME "amd64")
	endif ()
  endif(WIN32)
endif ()

message ("CPACK_SYSTEM_NAME ${CPACK_SYSTEM_NAME}")

set(CPACK_PACKAGE_NAME ${APP_NAME})
set(CPACK_PACKAGE_VENDOR ${APP_VENDOR})
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY ${APP_SUMMARY})
set(CPACK_PACKAGE_VERSION ${VERSION_SHORT})
if (WIN32)
  set(CPACK_PACKAGE_INSTALL_DIRECTORY ${APP_CREATOR})
  set(CPACK_WIX_LIGHT_EXTRA_FLAGS
    "-sval"
	)
  set(CPACK_WIX_CANDLE_EXTRA_FLAGS
    "-dCPACK_PACKAGE_INSTALL_DIRECTORY=${CPACK_PACKAGE_INSTALL_DIRECTORY}" 
    "-dCPACK_PACKAGE_DESCRIPTION_SUMMARY=${CPACK_PACKAGE_DESCRIPTION_SUMMARY}"
    "-dLONG_DESCRIPTION=${LONG_DESCRIPTION}"
    "-dAPP_CREATOR=${APP_CREATOR}"
    "-dPRODUCTEXE=${PRODUCTEXE}"
    "-dPFILESDIR=${PFILESDIR}"
    "-dAPP_ICO=${APP_ICO}"
    )
else(WIN32)
  set(CPACK_PACKAGE_INSTALL_DIRECTORY ${APP_NAME})
endif(WIN32)
set(CPACK_PACKAGE_CONTACT ${APP_CONTACT})
set(CPACK_GENERATOR ${SPECIFIC_SYSTEM_PREFERED_CPACK_GENERATOR})
set(CPACK_WIX_UPGRADE_GUID "826873C9-1A63-4A05-98F4-95D8D8EF3507")

include (CPack)
message ("CPACK_PACKAGE_FILE_NAME ${CPACK_PACKAGE_FILE_NAME}")
if (WIN32)
  include (WinSign)
endif(WIN32)
