{
  'variables': {
    'target_arch': 'ia32',
    # TODO: handle multiple agents somehow?
    'library_files': [
      'agents/monitoring/lua/init.lua',
      'agents/monitoring/lua/test.lua',
    ],
    'luvit_library_files': [
      'deps/luvit/lib/emitter.lua',
      'deps/luvit/lib/fiber.lua',
      'deps/luvit/lib/fs.lua',
      'deps/luvit/lib/http.lua',
      # We override what luvit.lua does in our own init function.
      # 'deps/luvit/lib/luvit.lua',
      'deps/luvit/lib/mime.lua',
      'deps/luvit/lib/path.lua',
      'deps/luvit/lib/pipe.lua',
      'deps/luvit/lib/process.lua',
      'deps/luvit/lib/repl.lua',
      'deps/luvit/lib/request.lua',
      'deps/luvit/lib/response.lua',
      'deps/luvit/lib/stack.lua',
      'deps/luvit/lib/stream.lua',
      'deps/luvit/lib/tcp.lua',
      'deps/luvit/lib/timer.lua',
      'deps/luvit/lib/tty.lua',
      'deps/luvit/lib/udp.lua',
      'deps/luvit/lib/url.lua',
      'deps/luvit/lib/utils.lua',
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
        '<@(library_files)',
        '<@(luvit_library_files)',
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
          'libraries': [ '-lpsapi.lib' ]
        },{ # POSIX
          'defines': [ '__POSIX__' ]
        }],
        [ 'OS=="mac"', {
          'libraries': [ '-framework Carbon' ]
        }],
        [ 'OS=="linux"', {
          'libraries': [
            '-ldl',
            '-lutil' # needed for openpty
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
            '<@(library_files)',
            '<@(luvit_library_files)',
          ],

          'outputs': [
            '<(PRODUCT_DIR)/monitoring.zip',
          ],

          'action': [
            'python',
            'tools/lua2zip.py',
            '<@(_outputs)',
            '<@(_inputs)',
            ],
        },
      ],
    }, # end monitoring.zip

  ] # end targets
}

