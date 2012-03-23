{
  'targets': [
    {
      'target_name': 'virgolib',
      'type': 'static_library',
      'conditions': [
        ['OS=="linux" or OS=="freebsd" or OS=="openbsd" or OS=="solaris"', {
          'cflags': [ '--std=c89' ],
          'defines': [ '_GNU_SOURCE' ]
        }],
      ],
      'dependencies': [
        '../deps/luvit/deps/zlib/zlib.gyp:zlib',
        '../deps/minizip.gyp:libminizip',
        '../deps/luvit/luvit.gyp:libluvit',
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
        'virgo_lua_tls.c',
        'virgo_lua_tls_conn.c',
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
