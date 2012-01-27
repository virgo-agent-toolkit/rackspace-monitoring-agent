{
  'targets': [
    {
      'target_name': 'virgolib',
      'type': 'static_library',
      'dependencies': [
        '../deps/zlib.gyp:zlib',
        '../deps/minizip.gyp:libminizip',
        '../deps/openssl.gyp:openssl',
        '../deps/luvit/luvit.gyp:libluvit',
        '../deps/luacrypto.gyp:luacrypto',
        '../deps/sigar.gyp:sigar',
        '../deps/sigar.gyp:lua_sigar',
      ],

      'defines': [
        'VIRGO_OS="<(OS)"',
      ],

      'sources': [
        'virgo_conf.c',
        'virgo_error.c',
        'virgo_init.c',
        'virgo_lua.c',
        'virgo_lua_loader.c',
        'virgo_lua_logging.c',
        'virgo_lua_debugger.c',
        'virgo_lua_vfs.c',
        'virgo_logging.c',
        'virgo_portable.c',
        'virgo_util.c',
        ],
      'include_dirs': [
          '.',
          '../include/private',
          '../include',
        ],
      'direct_dependent_settings': {
         'include_dirs': [
            '../include'
          ],
      },
    }
  ],
}
