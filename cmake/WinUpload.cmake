add_custom_target(packageupload
  COMMAND rclone --transfers=1 --checkers=2 mkdir ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
  COMMAND rclone --transfers=1 --checkers=2 copy ${MSI_OUTPUT} ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
)
