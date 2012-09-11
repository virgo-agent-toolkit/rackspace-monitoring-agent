{
  'target_defaults': {
    'include_dirs': [
      'sigar/include',
    ],
    'conditions': [
      [ 'OS=="win"',
        {
          'include_dirs': [
            'sigar/src/os/win32',
          ],
          'defines': [
            '_BIND_TO_CURRENT_MFC_VERSION=1',
            '_BIND_TO_CURRENT_CRT_VERSION=1',
            '_CRT_SECURE_NO_WARNINGS',
          ],
        },
        {
          # !win32
          'defines': [
            # TODO: detect this correctly.
            'HAVE_UTMPX_H',
          ],
        },
      ],
      ['OS=="mac" or OS=="freebsd"',
        {
          'include_dirs': [
            'sigar/src/os/darwin',
          ],
        }
      ],
      ['OS=="mac"',
        {
          'include_dirs': [
            '/Developer/Headers/FlatCarbon/',
          ],
          'defines': [
          # TODO: test on freebsd
            'DARWIN',
          ],
        }
      ],
      ['OS=="solaris"',
        {
          'include_dirs': [
            'sigar/src/os/solaris',
          ],
        }
      ],
      ['OS=="linux"',
        {
          'include_dirs': [
            'sigar/src/os/linux',
          ],
        }
      ],
    ],
  },

  'targets': [
    {
      'target_name': 'sigar',
      'type': 'static_library',
      'sources': [
        'sigar/src/sigar.c',
        'sigar/src/sigar_cache.c',
        'sigar/src/sigar_fileinfo.c',
        'sigar/src/sigar_format.c',
        'sigar/src/sigar_getline.c',
        'sigar/src/sigar_ptql.c',
        'sigar/src/sigar_signal.c',
        'sigar/src/sigar_util.c',
        'sigar-configs/sigar_version_autoconf_<(OS).c',
      ],
      'include_dirs': [
        'sigar/include',
      ],
      'direct_dependent_settings': {
        'include_dirs': [
          'sigar/include',
        ],
      },
      'conditions': [
        [ 'OS=="win"',
          {
            'sources': [
              'sigar/src/os/win32/peb.c',
              'sigar/src/os/win32/win32_sigar.c',
              'sigar/src/os/win32/wmi.cpp',
            ],
          }
        ],
        ['OS=="mac" or OS=="freebsd"',
          {
            'sources': [
              'sigar/src/os/darwin/darwin_sigar.c',
            ],
          }
        ],
        ['OS=="solaris"',
          {
            'sources': [
              'sigar/src/os/solaris/get_mib2.c',
              'sigar/src/os/solaris/kstats.c',
              'sigar/src/os/solaris/procfs.c',
              'sigar/src/os/solaris/solaris_sigar.c',
            ],
          }
        ],
        ['OS=="linux"',
          {
            'sources': [
              'sigar/src/os/linux/linux_sigar.c',
            ],
          }
        ],
      ],
    },
    {
      'target_name': 'lua_sigar',
      'type': 'static_library',
      'sources': [
        'sigar/bindings/lua/sigar.c',
        'sigar/bindings/lua/sigar-cpu.c',
        'sigar/bindings/lua/sigar-disk.c',
        'sigar/bindings/lua/sigar-fs.c',
        'sigar/bindings/lua/sigar-load.c',
        'sigar/bindings/lua/sigar-mem.c',
        'sigar/bindings/lua/sigar-netif.c',
        'sigar/bindings/lua/sigar-proc.c',
        'sigar/bindings/lua/sigar-swap.c',
        'sigar/bindings/lua/sigar-sysinfo.c',
        'sigar/bindings/lua/sigar-version.c',
        'sigar/bindings/lua/sigar-who.c',
      ],
      'include_dirs': [
        'sigar/bindings/lua',
        'lua/src',
      ],
      'direct_dependent_settings': {
        'include_dirs': [
          'sigar/bindings/lua',
        ]
      },
      'dependencies': [
        'luvit/deps/luajit.gyp:libluajit',
        'sigar.gyp:sigar',
      ],
    }
  ],
}

