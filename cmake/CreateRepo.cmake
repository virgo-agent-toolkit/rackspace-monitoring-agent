if (DEFINED FORCE_REPO_NAME)
  set(REPO_NAME ${FORCE_REPO_NAME})
else()
  set(REPO_NAME ${LINUX_NAME_LOWER}-${LINUX_VER}-${CMAKE_SYSTEM_PROCESSOR})
endif()
set(REPO_PATH ${CMAKE_BINARY_DIR}/${REPO_NAME})
message("Making repository ${REPO_NAME}")
add_custom_target(packagerepo
  COMMAND mkdir -p ${REPO_PATH}
  COMMAND cp ${CMAKE_BINARY_DIR}/*.rpm ${REPO_PATH}
  COMMAND rm -f ~/.rpmmacros
  COMMAND cp -f ${CMAKE_CURRENT_SOURCE_DIR}/cmake/package/rpm/rpm_macros_gpg ~/.rpmmacros
  COMMAND rpm --addsign ${REPO_PATH}/*.rpm
  COMMAND createrepo ${REPO_PATH}
  COMMAND gpg --detach-sign --armor ${REPO_PATH}/repodata/repomd.xml
)
add_custom_target(packagerepoupload
  COMMAND rclone --transfers=1 --checkers=2 mkdir ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}/${REPO_NAME}
  COMMAND rclone --transfers=1 --checkers=2 copy ${REPO_PATH} ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}/${REPO_NAME}
)
