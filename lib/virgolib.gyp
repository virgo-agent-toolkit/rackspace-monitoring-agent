{
  'targets': [
    {
      'target_name': 'virgolib',
      'type': 'static_library',
      'variables': {
        'bootstrap-luas': [
          '<!@(python ../tools/gyp_utils.py stupid_find lua)'
        ]
      },
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
        ['"<(without_ssl)" == "false"', {
          'defines': [ 'USE_OPENSSL' ],
        }],
      ],
      'dependencies': [
        '../deps/luvit/deps/zlib/zlib.gyp:zlib',
        '../deps/luvit/luvit.gyp:luvit',
        '../deps/luvit/luvit.gyp:libluvit',
        '../deps/sigar.gyp:sigar',
        '../deps/sigar.gyp:lua_sigar',
        './copy_luajiters.gyp:*'
      ],
      'export_dependent_settings': [
        '../deps/luvit/luvit.gyp:libluvit',
      ],
      'defines': [
        'VIRGO_OS="<(OS)"',
        'VIRGO_PLATFORM="<!(python ../tools/virgo_platform.py)"',
        'VIRGO_VERSION="<(VIRGO_HEAD_SHA)"',
        'VERSION_FULL="<(VERSION_FULL)"',
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
        'virgo_exports.c',
        '../deps/luvit/src/luvit_exports.c',
        '<@(bootstrap-luas)',
      ],
      'rules': [
        {
          'rule_name': 'bytecompile_lua',
          'extension': 'lua',
          'outputs': [
           '<(SHARED_INTERMEDIATE_DIR)/generated/<(RULE_INPUT_ROOT)_jit.c'
          ],
          'action': [
            'python', '../tools/gyp_utils.py', 'bytecompile_lua', '<(PRODUCT_DIR)', '<(RULE_INPUT_PATH)', '<@(_outputs)',
          ],
          'process_outputs_as_sources': 1,
          'message': 'luajit <(RULE_INPUT_PATH)'
        },
       ],
      'actions': [
       {
         #can't have two rules with the same extension... le sigh
         'action_name': 'generate_exports_file',
         'inputs': [
           '<@(bootstrap-luas)',
           '../tools/gyp_utils.py',
         ],
         'outputs': [
           'virgo_exports.c',
         ],
         'action': [
           'python',
           '../tools/gyp_utils.py',
           'virgo_exports',
           'virgo_exports.c',
           '<@(bootstrap-luas)',
         ],
	       'process_outputs_as_sources': 1,
       }
      ],
      'include_dirs': [
        '../include/private',
        '../include',
      ],
      'direct_dependent_settings': {
        'include_dirs': [
          '../include',
        ],
      },
    }
  ],
}
