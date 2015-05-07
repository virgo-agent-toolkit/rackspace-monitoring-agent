cmake_minimum_required(VERSION 2.8.9)

project(rackspace-monitoring-agent NONE)

set(APP_NAME    "rackspace-monitoring-agent")
set(APP_VENDOR  "Rackspace")
set(APP_SUMMARY "Rackspace Monitoring Agent")
set(APP_CONTACT "monitoring@rackspace.com")

if (DEFINED ENV{FORCE_REPO_NAME})
  set(FORCE_REPO_NAME $ENV{FORCE_REPO_NAME})
endif()

if (WIN32)
  set(APP_NAME_INSTALL  "${APP_NAME}.exe")
else()
  set(APP_NAME_INSTALL  "${APP_NAME}")
endif()

execute_process(
  COMMAND ./luvi ${CMAKE_CURRENT_SOURCE_DIR}/contrib/printversion
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  OUTPUT_VARIABLE VERSION_SHORT
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

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

install(PROGRAMS ${APP_NAME_INSTALL} DESTINATION bin)
install(FILES ${LICENSE_FILE} DESTINATION share/${APP_NAME})

if (${SPECIFIC_SYSTEM_VERSION_NAME} MATCHES "^Linux")
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

    set(CPACK_RPM_EXCLUDE_FROM_AUTO_FILELIST /etc/logrotate.d /etc/systemd /etc/init.d /usr/bin)

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
    set(CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA ${DEB_POSTRM} ${DEB_POSTINST}
      ${DEB_PRERM})

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
