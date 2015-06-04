if (MSI_OUTPUT_LEGACY)
  add_custom_target(packageupload
    COMMAND rclone --transfers=1 --checkers=2 mkdir ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
    COMMAND rclone --transfers=1 --checkers=2 copy ${MSI_OUTPUT} ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
    COMMAND rclone --transfers=1 --checkers=2 copy ${MSI_OUTPUT} ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}/${MSI_OUTPUT_LEGACY}
  )
else(MSI_OUTPUT_LEGACY)
  add_custom_target(packageupload
    COMMAND rclone --transfers=1 --checkers=2 mkdir ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
    COMMAND rclone --transfers=1 --checkers=2 copy ${MSI_OUTPUT} ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
  )
endif(MSI_OUTPUT_LEGACY)
