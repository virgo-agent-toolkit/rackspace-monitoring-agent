{
  'variables': {
    'target_arch': 'ia32',
  },

  'targets': [
    {
      'target_name': 'monitoring-agent',
      'type': 'executable',

      'dependencies': [
        'deps/http_parser/http_parser.gyp:http_parser',
        'deps/uv/uv.gyp:uv',
        'deps/zlib.gyp:zlib',
        'deps/minizip.gyp:libminizip',
        'lib/virgo.gyp:virgolib',
      ],

      'include_dirs': [
        'include',
      ],

      'sources': [
        'agents/monitoring/monitoring.c',
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
  ] # end targets
}

