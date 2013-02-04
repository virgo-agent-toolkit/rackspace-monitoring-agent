{
  'targets': [
    {
      'target_name': 'virgolib',
      'type': 'static_library',
      'conditions': [
        ['OS!="win"', {
          'sources': [
            'virgo_detach.c',
          ],
        }],
        ['OS=="linux" or OS=="freebsd" or OS=="openbsd" or OS=="solaris"', {
          'cflags': [ '--std=c89' ],
          'defines': [ '_GNU_SOURCE' ]
        }],
        ['OS=="linux"', {
          'dependencies': [
            '../deps/breakpad/breakpad.gyp:*'
          ],
          'sources': [
            'virgo_crash_reporter.cc',
          ],
          'include_dirs': [
            '../deps/breakpad/src',
          ],
        }],
        ['OS=="win"', {
          'sources': [
            'virgo_win32_service.c',
          ],
        }],
      ],
      'dependencies': [
        '../deps/luvit/deps/zlib/zlib.gyp:zlib',
        '../deps/luvit/luvit.gyp:luvit',
        '../deps/luvit/luvit.gyp:libluvit',
        '../deps/sigar.gyp:sigar',
        '../deps/sigar.gyp:lua_sigar',
      ],

      'export_dependent_settings': [
        '../deps/luvit/luvit.gyp:libluvit',
      ],

      'defines': [
        'VIRGO_OS="<(OS)"',
        'VIRGO_PLATFORM="<!(python ../tools/virgo_platform.py)"',
        'VIRGO_VERSION="<!(git --git-dir ../.git rev-parse HEAD)"',
        'VERSION_FULL="<!(python tools/version.py)"',
      ],

      'sources': [
        'virgo_agent_conf.c',
        'virgo_conf.c',
        'virgo_error.c',
        'virgo_exec.c',
        'virgo_init.c',
        'virgo_lua.c',
        'virgo_lua_loader.c',
        'virgo_lua_logging.c',
        'virgo_lua_debugger.c',
        'virgo_lua_paths.c',
        'virgo_lua_vfs.c',
        'virgo_logging.c',
        'virgo_paths.c',
        'virgo_portable.c',
        'virgo_time.c',
        'virgo_util.c',
        'virgo_versions.c',
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
