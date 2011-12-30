{
  'variables': {
    'target_arch': 'ia32',
    'lua_modules': [
      'lib/lua',
      'deps/luvit/lib',
      'lua_modules/async',
      'agents/monitoring/lua',
    ],
    'lua_modules_sources': [
      '<!@(python tools/bundle.py -l <(lua_modules))',
    ],
  },

  'targets': [
    {
      'target_name': 'monitoring-agent',
      'type': 'executable',

      'dependencies': [
        'lib/virgo.gyp:virgolib',
        'monitoring.zip#host',
      ],

      'include_dirs': [
        'include',
      ],

      'sources': [
        'agents/monitoring/monitoring.c',
        # lib files to make for an even more pleasant IDE experience
        '<@(lua_modules_sources)',
        'common.gypi',
      ],

      'defines': [
        'ARCH="<(target_arch)"',
        'PLATFORM="<(OS)"',
        '_LARGEFILE_SOURCE',
        '_FILE_OFFSET_BITS=64',
      ],

      'conditions': [
        [ 'OS=="win"', {
          'defines': [
            'FD_SETSIZE=1024',
            # we need to use node's preferred "win32" rather than gyp's preferred "win"
            'PLATFORM="win32"',
          ],
          'libraries': [ '-lpsapi.lib', '-lversion.lib', '-lnetapi32.lib' ]
        },{ # POSIX
          'defines': [ '__POSIX__' ]
        }],
        [ 'OS=="mac"', {
          'libraries': [ '-framework Carbon -framework IOKit' ]
        }],
        [ 'OS=="linux"', {
          'libraries': [
            '-ldl',
            '-lrt', # needed for clock_gettime
            '-lutil', # needed for openpty
          ],
        }],
        [ 'OS=="freebsd"', {
          'libraries': [
            '-lutil',
            '-lkvm',
          ],
        }],
        [ 'OS=="solaris"', {
          'libraries': [
            '-lkstat',
          ],
        }],
      ],
      'msvs-settings': {
        'VCLinkerTool': {
          'SubSystem': 1, # /subsystem:console
        },
      },
    },
    {
      'target_name': 'monitoring.zip',
      'type': 'none',
      'toolsets': ['host'],
      'variables': {
      },

      'actions': [
        {
          'action_name': 'virgo_luazip',

          'inputs': [       
            '<@(lua_modules_sources)',
            'tools/lua2zip.py',
          ],

          'outputs': [
            '<(PRODUCT_DIR)/monitoring.zip',
          ],

          'action': [
            'python',
            'tools/lua2zip.py',
            '<@(_outputs)',
            '<@(lua_modules)',
            ],
        },
      ],
    }, # end monitoring.zip

  ] # end targets
}

