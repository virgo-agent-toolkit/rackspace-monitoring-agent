{
  'targets': [
    {
      'target_name': 'luacrypto',
      'type': '<(library)',
      'dependencies': [
        'openssl.gyp:openssl',
        'luvit/deps/luajit.gyp:*',
        'luvit/luvit.gyp:libluvit',
      ],
      'sources': [
        'luacrypto/src/lcrypto.c',
      ],
      'include_dirs': [
        'luacrypto/src',
      ],
      'direct_dependent_settings': {
        'include_dirs': [
          'luacrypto/src',
        ]
      },
    }
  ],
}

