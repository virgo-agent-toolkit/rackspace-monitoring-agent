set(REPO_NAME ${LINUX_NAME_LOWER}-${LINUX_VER}-${CMAKE_SYSTEM_PROCESSOR})
set(REPO_PATH ${CMAKE_BINARY_DIR}/${REPO_NAME})
message("Making repository ${REPO_NAME}")
add_custom_target(packagerepo
  COMMAND mkdir -p ${REPO_PATH}
  COMMAND cp ${CMAKE_BINARY_DIR}/*.rpm ${REPO_PATH}
  COMMAND createrepo ${REPO_PATH}
)
add_custom_target(packagerepoupload
  COMMAND rclone copy ${REPO_PATH} ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}/${REPO_NAME}
)
