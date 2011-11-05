{
  'target_defaults': {
    'conditions': [
      ['OS != "win"', {
        'defines': [
          'USE_FILE32API',
        ],
      },
      ],
    ],
  },

  'targets': [
    {
      'target_name': 'libminizip',
      'type': 'static_library',
      'sources': [
        'minizip/unzip.c',
        'minizip/ioapi.c',
        'minizip/zip.c',
        ],
      'include_dirs': [
          'minizip',
          'zlib',
        ],
        'direct_dependent_settings': {
          'include_dirs': [
            'minizip',
          ],
        },
    }
  ],
}

