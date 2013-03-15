{
  'includes': [
    '../zirgo/pkg.gyp',
  ],
  'variables': {
    'luas': [
      '<!@(python tools/gyp_utils.py bundle_list <(BUNDLE_DIR))',
    ],
    'call_gyp': '<!(python tools/gyp_utils.py is_gyp_bundled <(BUNDLE_DIR))',
    'makefile_vars': [
      '<(PKG_NAME)',
      '<(BUNDLE_DIR)',
      '<(PKG_TYPE)',
      '<(VERSION_FULL)',
      '<(VERSION_RELEASE)',
      '<(VERSION_PATCH)',
      '<(PKG_NAME)-<(VERSION_FULL)',
      '<(SHORT_DESCRIPTION)',
      '<(LONG_DESCRIPTION)',
      '<(REPO)',
      '<(LICENSE)',
      '<(EMAIL)',
      '<(MAINTAINER)',
      '<(DOCUMENTATION_LINK)',
      '<@(CHANGELOG)',
    ],
    'hash_make_vars': '<!(python tools/gyp_utils.py hash <@(makefile_vars))',
  },
  'targets':
    [
      {
        'target_name': 'Makefile.in',
        'type': 'none',
        'actions': [
          {
            'action_name': 'Makefile.in',
            'inputs': ['tools/gyp_utils.py', 'pkg/Makefile.in'],
            'outputs': ['out/include.mk'],
            'action': ['python', 'tools/gyp_utils.py', 'pkg', '<@(makefile_vars)']
          }
        ],
        'dependencies': [
          '../zirgo/pkg.gyp:*',
        ],
      },
      {
        'target_name': 'bundle.zip',
        'type': 'none',
        'dependencies':[
          'Makefile.in'
        ],

        'actions': [
            {
              'action_name': 'bundle',
              'inputs': ['tools/gyp_utils.py', '<@(luas)'],
              'outputs': ["<(PRODUCT_DIR)/<(BUNDLE_NAME)-bundle.zip"],
              'action': [
                'python', 'tools/gyp_utils.py', 'make_bundle',
                '<(BUNDLE_DIR)', '<(BUNDLE_VERSION)', '<@(_outputs)', '<@(luas)'
              ]
            },
#        'conditions': [
#          ['"<(call_gyp)"=="1"', {
#            }, {  # no gyp file, just call this guy ourselves
#
#            ],
#          },
#        ],
      ],
    }
  ]
}
