{
  'variables': {
    'target_arch': 'ia32',
  },

  'targets': [
    {
      'target_name': 'virgo',
      'type': 'executable',

      'dependencies': [
        'lib/virgolib.gyp:virgolib',
      ],

      'include_dirs': [
        'include',
      ],

      'sources': [
        'lib/virgo.c',
        # lib files to make for an even more pleasant IDE experience
        'common.gypi',
      ],

      'defines': [
        'ARCH="<(target_arch)"',
        'PLATFORM="<(OS)"',
        '_LARGEFILE_SOURCE',
        '_FILE_OFFSET_BITS=64',
        'VERSION_FULL="<(VERSION_FULL)"',
      ],

      'actions': [
        {
          'action_name': 'generate_rc',
          'inputs': [
            'lib/virgo.rc.in'
          ],
          'outputs': [
            'lib/virgo.rc'
          ],
          'action': [
            'python',
            'tools/lame_sed.py',
            '<@(_inputs)',
            '<@(_outputs)',
            '{VERSION_FULL}:<(VERSION_FULL)',
            '{VERSION_MAJOR}:<(VERSION_MAJOR)',
            '{VERSION_MINOR}:<(VERSION_MINOR)',
            '{VERSION_PATCH}:<(VERSION_PATCH)',
            '{VERSION_RELEASE}:<(VERSION_RELEASE)',
          ],
        },
      ],
      'conditions': [
        [ 'OS=="win"',
          {
            'defines': [
              'FD_SETSIZE=1024'
            ],
            'libraries': [ '-lpsapi.lib', '-lversion.lib', '-lnetapi32.lib', '-lShlwapi.lib'],
            'sources': [
                'lib/virgo.rc',
            ],
          },
          { # POSIX
            'defines': [ '__POSIX__' ]
          }
        ],
        [ 'OS=="mac"',
          {
            'libraries': [ 'Carbon.framework', 'IOKit.framework' ]
          }
        ],
        [ 'OS=="linux"',
          {
            'libraries': [
              '-ldl',
              '-lrt', # needed for clock_gettime
              '-lutil', # needed for openpty
            ],
          }
        ],
        [ 'OS=="freebsd"',
          {
            'libraries': [
              '-lutil',
              '-lkvm',
            ],
          }
        ],
        [ 'OS=="solaris"',
          {
            'libraries': [
              '-lkstat',
            ],
          }
        ],
      ],
      'msvs-settings': {
        'VCLinkerTool': {
          'SubSystem': 1, # /subsystem:console
        },
      },
    },
  ],# end targets

  'conditions': [
    [ 'OS=="win"', {
      'targets': [
        {
          'target_name': 'rackspace-monitoring-agent.msi',
          'type': 'none',
          'dependencies': [
            'monitoring-agent#host',
          ],

          'sources': [
            'pkg/windows/RackspaceMonitoringAgent.wxs',
          ],

          'actions': [ {
            'action_name': 'candle',
            'inputs': [
              'pkg/windows/RackspaceMonitoringAgent.wxs',
              '<(INTERMEDIATE_DIR)/version.wxi',
            ],
            'outputs': [
              '<(INTERMEDIATE_DIR)/RackspaceMonitoringAgent.wixobj',
            ],
            'action': [
              '<(CANDLE_EXE)',
              '-out',
              '<@(_outputs)',
              'pkg/windows/RackspaceMonitoringAgent.wxs',
              '-dVERSIONFULL=<(VERSION_FULL)',
              '-dPRODUCTDIR=<(PRODUCT_DIR)',
              '-dREPODIR=<(RULE_INPUT_DIRNAME)',
            ],
            'process_outputs_as_sources': 1,
          },
          {
            'action_name': 'light',
            'extension': 'wxs',
            'inputs': [
              '<(INTERMEDIATE_DIR)/RackspaceMonitoringAgent.wixobj',
              '<(PRODUCT_DIR)/monitoring-agent.exe',
            ],
            'outputs': [
              '<(PRODUCT_DIR)/rackspace-monitoring-agent.msi',
            ],
            'action': [
              '<(LIGHT_EXE)',
              '<(INTERMEDIATE_DIR)/RackspaceMonitoringAgent.wixobj',
              '-ext', 'WixUIExtension',
              '-ext', 'WixUtilExtension',
              '-out', '<@(_outputs)',
            ],
            'process_outputs_as_sources': 1,
          }]
        }], #end targets
    }], #end win32
  ],
}

