if (DEFINED FORCE_REPO_NAME)
  set(REPO_NAME ${FORCE_REPO_NAME})
else()
  set(REPO_NAME ${LINUX_NAME_LOWER}-${LINUX_VER}-${CMAKE_SYSTEM_PROCESSOR})
endif()
set(REPO_PATH ${CMAKE_BINARY_DIR}/${REPO_NAME})
message("Creating ${REPO_NAME} Repository")
configure_file(${REPOSITORY_SCRIPTS}/reprepro.in ${REPO_PATH}/conf/distributions)
add_custom_target(packagerepo
  COMMAND reprepro -b ${REPO_PATH} includedeb ${REPO_RPM_NAME} *.deb
)
add_custom_target(packagerepoupload
  COMMAND rclone --transfers=1 --checkers=2 mkdir ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}/${REPO_NAME}
  COMMAND rclone --transfers=1 --checkers=2 copy ${REPO_PATH} ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}/${REPO_NAME}
)
