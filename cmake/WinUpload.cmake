if (MSI_OUTPUT_LEGACY)
  add_custom_target(packageupload
    COMMAND rclone mkdir ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
    COMMAND rclone copy ${MSI_OUTPUT} ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
    COMMAND copy ${MSI_OUTPUT} ${MSI_OUTPUT_LEGACY}
    COMMAND rclone copy ${MSI_OUTPUT_LEGACY} ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
  )
else(MSI_OUTPUT_LEGACY)
  add_custom_target(packageupload
    COMMAND rclone mkdir ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
    COMMAND rclone copy ${MSI_OUTPUT} ${REPO_UPLOAD_CLOUD}:${VERSION_SHORT}
  )
endif(MSI_OUTPUT_LEGACY)
