{
  'targets': [{
    'target_name': 'copy_luajit',
    'type': 'none',
    'copies': [
        # the luajit interpreter needs these to be able to bytecompile .lua => .c
        {
          "destination": "<(PRODUCT_DIR)",
          "files": ["<(PRODUCT_DIR)/lua/jit"]
        },
      ],
    }
  ]
}