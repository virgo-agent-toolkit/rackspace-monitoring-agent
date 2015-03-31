set(REPO_DIRECTORY ${CMAKE_BINARY_DIR}/repository)
configure_file(${REPOSITORY_SCRIPTS}/reprepro.in ${REPO_DIRECTORY}/conf/distributions)
add_custom_target(packagerepo
  COMMAND reprepro -b ${REPO_DIRECTORY} includedeb cloudmonitoring *.deb
)
