{
  'variables': {
    'bundle_version': '<!(python tools/version.py -d "<(bundle_dir)")',
    'luas': [
      '<!@(python tools/gyp_utils.py bundle_list <(bundle_dir) tests)',
    ],
    'test-luas': [
      '<!@(python tools/gyp_utils.py bundle_list <(bundle_dir))',
    ],
    'call_gyp': '<!(python tools/gyp_utils.py is_gyp_bundled <(bundle_dir))',
  },
  'targets':
    [
      {
        'target_name': 'bundle.zip',
        'type': 'none',
        'conditions': [
          ['"<(call_gyp)"=="1"', {
            }, {  # no gyp file, just call this guy ourselves
            'actions': [
              {
                'action_name': 'bundle',
                'inputs': ['tools/gyp_utils.py', '<@(luas)'],
                'outputs': ["<(PRODUCT_DIR)/<(bundle_name)-bundle.zip"],
                'action': [
                  'python', 'tools/gyp_utils.py', 'make_bundle',
                  '<(bundle_dir)', '<(bundle_version)', '<@(_outputs)', '<@(luas)'
                ]
              },
              {
                'action_name': 'bundle-test',
                'inputs': ['tools/gyp_utils.py', '<@(test-luas)'],
                'outputs': ["<(PRODUCT_DIR)/<(bundle_name)-bundle-test.zip"],
                'action': [
                  'python', 'tools/gyp_utils.py', 'make_bundle',
                  '<(bundle_dir)', '<(bundle_version)', '<@(_outputs)', '<@(test-luas)'
                ]
              },
            ],
          },
        ],
      ],
    }
  ]
}
