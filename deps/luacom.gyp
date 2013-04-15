{
  'targets': [
    {
      'target_name': 'luacom',
      'type': 'static_library',
      'sources': [
        'luacom/src/library/LuaAux.cpp',
        'luacom/src/library/luabeans.cpp',
        'luacom/src/library/luacom.cpp',
        'luacom/src/library/LuaCompat.cpp',
        'luacom/src/library/tCOMUtil.cpp',
        'luacom/src/library/tLuaCOM.cpp',
        'luacom/src/library/tLuaCOMClassFactory.cpp',
        'luacom/src/library/tLuaCOMConnPoints.cpp',
        'luacom/src/library/tLuaCOMEnumerator.cpp',
        'luacom/src/library/tLuaCOMException.cpp',
        'luacom/src/library/tLuaCOMTypeHandler.cpp',
        'luacom/src/library/tLuaControl.cpp',
        'luacom/src/library/tLuaDispatch.cpp',
        'luacom/src/library/tLuaObject.cpp',
        'luacom/src/library/tLuaObjList.cpp',
        'luacom/src/library/tLuaTLB.cpp',
        'luacom/src/library/tLuaVector.cpp',
        'luacom/src/library/tStringBuffer.cpp',
        'luacom/src/library/tUtil.cpp',
      ],
      'include_dirs': [
        'luacom/src/library',
        'luacom/include',
        'lua/src',
        '../lib',
      ],
      'direct_dependent_settings': {
        'include_dirs': [
          'luacom/src/library',
        ]
      },
      'defines': [
        'LUACOM_DLL="rackspace-monitoring-agent.exe"',
        'NOMINMAX',
        'NO_HTMLHELP',
        'g_NULL=NULL',
      ],
      'dependencies': [
        'luvit/deps/luajit.gyp:libluajit',
      ],
    }
  ],
}

