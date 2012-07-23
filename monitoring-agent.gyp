{
  'variables': {
    'target_arch': 'ia32',
    'modules_agent': [
      'lib/lua',
      'deps/luvit/lib/luvit',
      'modules/async',
      'modules/bourbon',
      'modules/options',
      'modules/luvit-keystone-client',
      'modules/luvit-rackspace-monitoring-client',
      'modules/line-emitter',
      'agents/monitoring/default',
      'agents/monitoring/init.lua',
    ],
    'modules_collector': [
      'lib/lua',
      'deps/luvit/lib/luvit',
      'modules/async',
      'modules/bourbon',
      'modules/options',
      'modules/traceroute',
      'modules/line-emitter',
      'agents/monitoring/collector',
      'agents/monitoring/init.lua',
    ],
    'modules_sources_agent': [
      '<!@(python tools/bundle.py -l <(modules_agent))',
    ],
    'modules_sources_collector': [
      '<!@(python tools/bundle.py -l <(modules_collector))',
    ],
    'test_modules': [
      '<@(modules_agent)',
      '<@(modules_collector)',
      'agents/monitoring/tests',
      'agents/monitoring/tests/tls',
      'agents/monitoring/tests/crypto',
      'agents/monitoring/tests/agent-protocol',
    ],
    'test_modules_sources': [
      '<!@(python tools/bundle.py -l <(test_modules))',
    ],
  },

  'targets': [
    {
      'target_name': 'monitoring-agent',
      'type': 'executable',

      'dependencies': [
        'lib/virgo.gyp:virgolib',
        'monitoring.zip#host',
        'monitoring-test.zip#host',
        'collector.zip#host',
      ],

      'include_dirs': [
        'include',
      ],

      'sources': [
        'agents/monitoring/monitoring.c',
        # lib files to make for an even more pleasant IDE experience
        '<@(modules_sources_agent)',
        'common.gypi',
      ],

      'defines': [
        'ARCH="<(target_arch)"',
        'PLATFORM="<(OS)"',
        '_LARGEFILE_SOURCE',
        '_FILE_OFFSET_BITS=64',
        'VIRGO_VERSION="<!(git --git-dir .git rev-parse HEAD)"',
      ],

      'conditions': [
        [ 'OS=="win"',
          {
            'defines': [
              'FD_SETSIZE=1024'
            ],
            'libraries': [ '-lpsapi.lib', '-lversion.lib', '-lnetapi32.lib', '-lShlwapi.lib']
          },
          { # POSIX
            'defines': [ '__POSIX__' ]
          }
        ],
        [ 'OS=="mac"',
          {
            'libraries': [ '-framework Carbon -framework IOKit' ]
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
    {
      'target_name': 'versions',
      'type': 'none',
      'toolsets': ['host'],
      'variables': {
        'BUNDLE_VERSION': '<!(git --git-dir .git describe --tags)'
      },
      'actions': [
        {
          'action_name': 'generate_version',
          'inputs': [
            'agents/monitoring/default/util/version.lua.in'
          ],
          'outputs': [
            'agents/monitoring/default/util/version.lua'
          ],
          'action': [
            'python',
            'tools/lame_sed.py',
            '<@(_inputs)',
            '<@(_outputs)',
            '{AGENT_BUNDLE_VERSION}:<(BUNDLE_VERSION)'
          ]
        }
      ]
    },
    {
      'target_name': 'monitoring.zip',
      'type': 'none',
      'toolsets': ['host'],
      'variables': {
      },
      'dependencies': [
        'versions#host'
      ],
      'actions': [
        {
          'action_name': 'virgo_luazip',

          'inputs': [
            '<@(modules_sources_agent)',
            'tools/lua2zip.py',
          ],

          'outputs': [
            '<(PRODUCT_DIR)/monitoring.zip',
          ],

          'action': [
            'python',
            'tools/lua2zip.py',
            '<@(_outputs)',
            '<@(modules_agent)',
          ],
        },
      ],
    }, # end monitoring.zip
    {
      'target_name': 'monitoring-test.zip',
      'type': 'none',
      'toolsets': ['host'],
      'variables': {
      },

      'actions': [
        {
          'action_name': 'virgo_luazip',

          'inputs': [
            '<@(test_modules_sources)',
            'tools/lua2zip.py',
          ],

          'outputs': [
            '<(PRODUCT_DIR)/monitoring-test.zip',
          ],

          'action': [
            'python',
            'tools/lua2zip.py',
            '<@(_outputs)',
            '<@(test_modules)',
          ],
        },
      ],
    }, # end monitoring-test.zip
    {
      'target_name': 'collector.zip',
      'type': 'none',
      'toolsets': ['host'],
      'variables': {
      },

      'actions': [
        {
          'action_name': 'virgo_luazip',

          'inputs': [
            '<@(modules_sources_collector)',
            'tools/lua2zip.py',
          ],

          'outputs': [
            '<(PRODUCT_DIR)/collector.zip',
          ],

          'action': [
            'python',
            'tools/lua2zip.py',
            '<@(_outputs)',
            '<@(modules_collector)',
          ],
        },
      ],
    }
  ] # end targets
}

