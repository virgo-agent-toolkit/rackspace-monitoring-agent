# Windows Signing
set(CODESIGNING_KEYFILE "$ENV{RACKSPACE_CODESIGNING_KEYFILE}")
if (CODESIGNING_KEYFILE STREQUAL "")
  # Sign with Test Key
  set(CODESIGNING_KEYFILE "${PACKAGE_SCRIPTS}/windows/testss.pfx")
endif()

find_path(
  SIGNTOOL_PATH
  NAMES "signtool.exe"
  PATHS
    "C:\\Program Files (x86)\\Microsoft SDKs\\Windows\\v7.1A\\bin"
    "C:\\Program Files (x86)\\Microsoft SDKs\\Windows\\v7.0A\\bin"
    NO_DEFAULT_PATH
)
message("SignTool.exe found in: ${SIGNTOOL_PATH}")

add_custom_target(
  SignExe
  COMMAND "${SIGNTOOL_PATH}\\signtool.exe" sign /d ${APP_NAME_INSTALL} /v /f ${CODESIGNING_KEYFILE} ${APP_NAME_INSTALL}
  DEPENDS ${APP_NAME_INSTALL}
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
)

set(MSI_OUTPUT "${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-AMD64.msi")

add_custom_target(
  SignPackage
  COMMAND "${SIGNTOOL_PATH}\\signtool.exe" sign /d ${APP_NAME_INSTALL} /v /f ${CODESIGNING_KEYFILE} ${MSI_OUTPUT}
  DEPENDS ${MSI_OUTPUT}
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
)

