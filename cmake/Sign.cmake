## SIGNATURE_KEY path required

set(_SIGNATURE_NAME ${LINUX_NAME_LOWER}-${LINUX_VER}-${CMAKE_SYSTEM_PROCESSOR}-${APP_NAME}-${VERSION_SHORT})
set(_SIGNATURE_EXE_RAW ${CMAKE_CURRENT_SOURCE_DIR}/${APP_NAME})

set(SIGNATURE_EXE ${CMAKE_BINARY_DIR}/${_SIGNATURE_NAME})
set(SIGNATURE_SIG ${CMAKE_BINARY_DIR}/${_SIGNATURE_NAME}.sig)
get_filename_component(_SIGNATURE_KEY_PATH ${SIGNATURE_KEY} ABSOLUTE)
if(EXISTS ${_SIGNATURE_KEY_PATH})
  add_custom_target(siggen
    COMMAND openssl dgst -sha256 -sign ${_SIGNATURE_KEY_PATH} ${_SIGNATURE_EXE_RAW} > ${SIGNATURE_SIG}
    COMMAND cp -f ${_SIGNATURE_EXE_RAW} ${SIGNATURE_EXE}
  )
  add_custom_target(siggenupload
    COMMAND rclone mkdir ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
    COMMAND rclone copy ${SIGNATURE_EXE} ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
    COMMAND rclone copy ${SIGNATURE_SIG} ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
  )
else()
  add_custom_target(siggen echo no ~/server.key found)
  add_custom_target(siggenupload echo no upload specified)
endif()
