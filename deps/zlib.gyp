{
  'target_defaults': {
    'conditions': [
      ['OS != "win"',
        {
          'defines': [
            '_LARGEFILE_SOURCE',
            '_FILE_OFFSET_BITS=64',
            '_GNU_SOURCE',
            'HAVE_SYS_TYPES_H',
            'HAVE_STDINT_H',
            'HAVE_STDDEF_H',
          ],
        },
        { # windows
          'defines': [
            '_CRT_SECURE_NO_DEPRECATE',
            '_CRT_NONSTDC_NO_DEPRECATE',
          ],
        },
      ],
    ],
  },

  'targets': [
    {
      'target_name': 'zlib',
      'type': 'static_library',
      'sources': [
        'zlib/adler32.c',
        'zlib/compress.c',
        'zlib/crc32.c',
        'zlib/deflate.c',
        'zlib/gzclose.c',
        'zlib/gzlib.c',
        'zlib/gzread.c',
        'zlib/gzwrite.c',
        'zlib/inflate.c',
        'zlib/infback.c',
        'zlib/inftrees.c',
        'zlib/inffast.c',
        'zlib/trees.c',
        'zlib/uncompr.c',
        'zlib/zutil.c',
        'zlib/win32/zlib1.rc'
      ],
      'include_dirs': [
        'zlib',
      ],
      'direct_dependent_settings': {
        'include_dirs': [
          'zlib',
        ],
      },
    }
  ],
}

