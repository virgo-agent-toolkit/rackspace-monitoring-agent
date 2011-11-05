{
  'targets': [
    {
      'target_name': 'virgolib',
      'type': 'static_library',
      'sources': [
        'virgo_conf.c',
        'virgo_error.c',
        'virgo_init.c',
        'virgo_lua.c',
        'virgo_lua_loader.c',
        'virgo_lua_debugger.c',
        ],
      'include_dirs': [
          '.',
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
