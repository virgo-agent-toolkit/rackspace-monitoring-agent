# Copyright (c) 2012 Google Inc. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""
This module helps emulate Visual Studio 2008 behavior on top of other
build systems, primarily ninja.
"""

import os
import re
import subprocess
import sys

import gyp.MSVSVersion

windows_quoter_regex = re.compile(r'(\\*)"')

def QuoteForRspFile(arg):
  """Quote a command line argument so that it appears as one argument when
  processed via cmd.exe and parsed by CommandLineToArgvW (as is typical for
  Windows programs)."""
  # See http://goo.gl/cuFbX and http://goo.gl/dhPnp including the comment
  # threads. This is actually the quoting rules for CommandLineToArgvW, not
  # for the shell, because the shell doesn't do anything in Windows. This
  # works more or less because most programs (including the compiler, etc.)
  # use that function to handle command line arguments.

  # For a literal quote, CommandLineToArgvW requires 2n+1 backslashes
  # preceding it, and results in n backslashes + the quote. So we substitute
  # in 2* what we match, +1 more, plus the quote.
  arg = windows_quoter_regex.sub(lambda mo: 2 * mo.group(1) + '\\"', arg)

  # %'s also need to be doubled otherwise they're interpreted as batch
  # positional arguments. Also make sure to escape the % so that they're
  # passed literally through escaping so they can be singled to just the
  # original %. Otherwise, trying to pass the literal representation that
  # looks like an environment variable to the shell (e.g. %PATH%) would fail.
  arg = arg.replace('%', '%%')

  # These commands are used in rsp files, so no escaping for the shell (via ^)
  # is necessary.

  # Finally, wrap the whole thing in quotes so that the above quote rule
  # applies and whitespace isn't a word break.
  return '"' + arg + '"'


def EncodeRspFileList(args):
  """Process a list of arguments using QuoteCmdExeArgument."""
  # Note that the first argument is assumed to be the command. Don't add
  # quotes around it because then built-ins like 'echo', etc. won't work.
  # Take care to normpath only the path in the case of 'call ../x.bat' because
  # otherwise the whole thing is incorrectly interpreted as a path and not
  # normalized correctly.
  if not args: return ''
  if args[0].startswith('call '):
    call, program = args[0].split(' ', 1)
    program = call + ' ' + os.path.normpath(program)
  else:
    program = os.path.normpath(args[0])
  return program + ' ' + ' '.join(QuoteForRspFile(arg) for arg in args[1:])


def _GenericRetrieve(root, default, path):
  """Given a list of dictionary keys |path| and a tree of dicts |root|, find
  value at path, or return |default| if any of the path doesn't exist."""
  if not root:
    return default
  if not path:
    return root
  return _GenericRetrieve(root.get(path[0]), default, path[1:])


def _AddPrefix(element, prefix):
  """Add |prefix| to |element| or each subelement if element is iterable."""
  if element is None:
    return element
  # Note, not Iterable because we don't want to handle strings like that.
  if isinstance(element, list) or isinstance(element, tuple):
    return [prefix + e for e in element]
  else:
    return prefix + element


def _DoRemapping(element, map):
  """If |element| then remap it through |map|. If |element| is iterable then
  each item will be remapped. Any elements not found will be removed."""
  if map is not None and element is not None:
    if not callable(map):
      map = map.get # Assume it's a dict, otherwise a callable to do the remap.
    if isinstance(element, list) or isinstance(element, tuple):
      element = filter(None, [map(elem) for elem in element])
    else:
      element = map(element)
  return element


def _AppendOrReturn(append, element):
  """If |append| is None, simply return |element|. If |append| is not None,
  then add |element| to it, adding each item in |element| if it's a list or
  tuple."""
  if append is not None and element is not None:
    if isinstance(element, list) or isinstance(element, tuple):
      append.extend(element)
    else:
      append.append(element)
  else:
    return element


def _FindDirectXInstallation():
  """Try to find an installation location for the DirectX SDK. Check for the
  standard environment variable, and if that doesn't exist, try to find
  via the registry. May return None if not found in either location."""
  dxsdk_dir = os.environ.get('DXSDK_DIR')
  if not dxsdk_dir:
    # Setup params to pass to and attempt to launch reg.exe.
    cmd = ['reg.exe', 'query', r'HKLM\Software\Microsoft\DirectX', '/s']
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    for line in p.communicate()[0].splitlines():
      if 'InstallPath' in line:
        dxsdk_dir = line.split('    ')[3] + "\\"
  return dxsdk_dir


class MsvsSettings(object):
  """A class that understands the gyp 'msvs_...' values (especially the
  msvs_settings field). They largely correpond to the VS2008 IDE DOM. This
  class helps map those settings to command line options."""

  def __init__(self, spec, generator_flags):
    self.spec = spec
    self.vs_version = GetVSVersion(generator_flags)
    self.dxsdk_dir = _FindDirectXInstallation()

    # Try to find an installation location for the Windows DDK by checking
    # the WDK_DIR environment variable, may be None.
    self.wdk_dir = os.environ.get('WDK_DIR')

    supported_fields = [
        ('msvs_configuration_attributes', dict),
        ('msvs_settings', dict),
        ('msvs_system_include_dirs', list),
        ('msvs_disabled_warnings', list),
        ('msvs_precompiled_header', str),
        ('msvs_precompiled_source', str),
        ]
    configs = spec['configurations']
    for field, default in supported_fields:
      setattr(self, field, {})
      for configname, config in configs.iteritems():
        getattr(self, field)[configname] = config.get(field, default())

    self.msvs_cygwin_dirs = spec.get('msvs_cygwin_dirs', ['.'])

  def GetVSMacroEnv(self, base_to_build=None):
    """Get a dict of variables mapping internal VS macro names to their gyp
    equivalents."""
    replacements = {
        '$(VSInstallDir)': self.vs_version.Path(),
        '$(VCInstallDir)': os.path.join(self.vs_version.Path(), 'VC') + '\\',
        '$(OutDir)\\': base_to_build + '\\' if base_to_build else '',
        '$(IntDir)': '$!INTERMEDIATE_DIR',
        '$(InputPath)': '${source}',
        '$(InputName)': '${root}',
        '$(ProjectName)': self.spec['target_name'],
        '$(PlatformName)': 'Win32', # TODO(scottmg): Support for x64 toolchain.
    }
    # Chromium uses DXSDK_DIR in include/lib paths, but it may or may not be
    # set. This happens when the SDK is sync'd via src-internal, rather than
    # by typical end-user installation of the SDK. If it's not set, we don't
    # want to leave the unexpanded variable in the path, so simply strip it.
    replacements['$(DXSDK_DIR)'] = self.dxsdk_dir if self.dxsdk_dir else ''
    replacements['$(WDK_DIR)'] = self.wdk_dir if self.wdk_dir else ''
    return replacements

  def ConvertVSMacros(self, s, base_to_build=None):
    """Convert from VS macro names to something equivalent."""
    env = self.GetVSMacroEnv(base_to_build)
    return ExpandMacros(s, env)

  def AdjustLibraries(self, libraries):
    """Strip -l from library if it's specified with that."""
    return [lib[2:] if lib.startswith('-l') else lib for lib in libraries]

  def _GetAndMunge(self, field, path, default, prefix, append, map):
    """Retrieve a value from |field| at |path| or return |default|. If
    |append| is specified, and the item is found, it will be appended to that
    object instead of returned. If |map| is specified, results will be
    remapped through |map| before being returned or appended."""
    result = _GenericRetrieve(field, default, path)
    result = _DoRemapping(result, map)
    result = _AddPrefix(result, prefix)
    return _AppendOrReturn(append, result)

  class _GetWrapper(object):
    def __init__(self, parent, field, base_path, append=None):
      self.parent = parent
      self.field = field
      self.base_path = [base_path]
      self.append = append
    def __call__(self, name, map=None, prefix='', default=None):
      return self.parent._GetAndMunge(self.field, self.base_path + [name],
          default=default, prefix=prefix, append=self.append, map=map)

  def _Setting(self, path, config,
              default=None, prefix='', append=None, map=None):
    """_GetAndMunge for msvs_settings."""
    return self._GetAndMunge(
        self.msvs_settings[config], path, default, prefix, append, map)

  def _ConfigAttrib(self, path, config,
                   default=None, prefix='', append=None, map=None):
    """_GetAndMunge for msvs_configuration_attributes."""
    return self._GetAndMunge(
        self.msvs_configuration_attributes[config],
        path, default, prefix, append, map)

  def AdjustIncludeDirs(self, include_dirs, config):
    """Updates include_dirs to expand VS specific paths, and adds the system
    include dirs used for platform SDK and similar."""
    includes = include_dirs + self.msvs_system_include_dirs[config]
    includes.extend(self._Setting(
      ('VCCLCompilerTool', 'AdditionalIncludeDirectories'), config, default=[]))
    return [self.ConvertVSMacros(p) for p in includes]

  def GetComputedDefines(self, config):
    """Returns the set of defines that are injected to the defines list based
    on other VS settings."""
    defines = []
    if self._ConfigAttrib(['CharacterSet'], config) == '1':
      defines.extend(('_UNICODE', 'UNICODE'))
    if self._ConfigAttrib(['CharacterSet'], config) == '2':
      defines.append('_MBCS')
    defines.extend(self._Setting(
        ('VCCLCompilerTool', 'PreprocessorDefinitions'), config, default=[]))
    return defines

  def GetOutputName(self, config, expand_special):
    """Gets the explicitly overridden output name for a target or returns None
    if it's not overridden."""
    type = self.spec['type']
    root = 'VCLibrarianTool' if type == 'static_library' else 'VCLinkerTool'
    # TODO(scottmg): Handle OutputDirectory without OutputFile.
    output_file = self._Setting((root, 'OutputFile'), config)
    if output_file:
      output_file = expand_special(self.ConvertVSMacros(output_file))
    return output_file

  def GetCflags(self, config):
    """Returns the flags that need to be added to .c and .cc compilations."""
    cflags = []
    cflags.extend(['/wd' + w for w in self.msvs_disabled_warnings[config]])
    cl = self._GetWrapper(self, self.msvs_settings[config],
                          'VCCLCompilerTool', append=cflags)
    cl('Optimization',
       map={'0': 'd', '1': '1', '2': '2', '3': 'x'}, prefix='/O')
    cl('InlineFunctionExpansion', prefix='/Ob')
    cl('OmitFramePointers', map={'false': '-', 'true': ''}, prefix='/Oy')
    cl('FavorSizeOrSpeed', map={'1': 't', '2': 's'}, prefix='/O')
    cl('WholeProgramOptimization', map={'true': '/GL'})
    cl('WarningLevel', prefix='/W')
    cl('WarnAsError', map={'true': '/WX'})
    cl('DebugInformationFormat',
        map={'1': '7', '3': 'i', '4': 'I'}, prefix='/Z')
    cl('RuntimeTypeInfo', map={'true': '/GR', 'false': '/GR-'})
    cl('EnableFunctionLevelLinking', map={'true': '/Gy', 'false': '/Gy-'})
    cl('MinimalRebuild', map={'true': '/Gm'})
    cl('BufferSecurityCheck', map={'true': '/GS', 'false': '/GS-'})
    cl('BasicRuntimeChecks', map={'1': 's', '2': 'u', '3': '1'}, prefix='/RTC')
    cl('RuntimeLibrary',
        map={'0': 'T', '1': 'Td', '2': 'D', '3': 'Dd'}, prefix='/M')
    cl('ExceptionHandling', map={'1': 'sc','2': 'a'}, prefix='/EH')
    cl('AdditionalOptions', prefix='')
    # ninja handles parallelism by itself, don't have the compiler do it too.
    cflags = filter(lambda x: not x.startswith('/MP'), cflags)
    return cflags

  def GetPrecompiledHeader(self, config, gyp_to_build_path):
    """Returns an object that handles the generation of precompiled header
    build steps."""
    return _PchHelper(self, config, gyp_to_build_path)

  def _GetPchFlags(self, config, extension):
    """Get the flags to be added to the cflags for precompiled header support.
    """
    # The PCH is only built once by a particular source file. Usage of PCH must
    # only be for the same language (i.e. C vs. C++), so only include the pch
    # flags when the language matches.
    if self.msvs_precompiled_header[config]:
      source_ext = os.path.splitext(self.msvs_precompiled_source[config])[1]
      if _LanguageMatchesForPch(source_ext, extension):
        pch = os.path.split(self.msvs_precompiled_header[config])[1]
        return ['/Yu' + pch, '/FI' + pch, '/Fp${pchprefix}.' + pch + '.pch']
    return  []

  def GetCflagsC(self, config):
    """Returns the flags that need to be added to .c compilations."""
    return self._GetPchFlags(config, '.c')

  def GetCflagsCC(self, config):
    """Returns the flags that need to be added to .cc compilations."""
    return ['/TP'] + self._GetPchFlags(config, '.cc')

  def _GetAdditionalLibraryDirectories(self, root, config, gyp_to_build_path):
    """Get and normalize the list of paths in AdditionalLibraryDirectories
    setting."""
    libpaths = self._Setting((root, 'AdditionalLibraryDirectories'),
                             config, default=[])
    libpaths = [os.path.normpath(gyp_to_build_path(self.ConvertVSMacros(p)))
                for p in libpaths]
    return ['/LIBPATH:"' + p + '"' for p in libpaths]

  def GetLibFlags(self, config, gyp_to_build_path):
    """Returns the flags that need to be added to lib commands."""
    libflags = []
    lib = self._GetWrapper(self, self.msvs_settings[config],
                          'VCLibrarianTool', append=libflags)
    libflags.extend(self._GetAdditionalLibraryDirectories(
        'VCLibrarianTool', config, gyp_to_build_path))
    lib('AdditionalOptions')
    return libflags

  def _GetDefFileAsLdflags(self, spec, ldflags, gyp_to_build_path):
    """.def files get implicitly converted to a ModuleDefinitionFile for the
    linker in the VS generator. Emulate that behaviour here."""
    def_file = ''
    if spec['type'] in ('shared_library', 'loadable_module', 'executable'):
      def_files = [s for s in spec.get('sources', []) if s.endswith('.def')]
      if len(def_files) == 1:
        ldflags.append('/DEF:"%s"' % gyp_to_build_path(def_files[0]))
      elif len(def_files) > 1:
        raise Exception("Multiple .def files")

  def GetLdflags(self, config, gyp_to_build_path, expand_special):
    """Returns the flags that need to be added to link commands."""
    ldflags = []
    ld = self._GetWrapper(self, self.msvs_settings[config],
                          'VCLinkerTool', append=ldflags)
    self._GetDefFileAsLdflags(self.spec, ldflags, gyp_to_build_path)
    ld('GenerateDebugInformation', map={'true': '/DEBUG'})
    ld('TargetMachine', map={'1': 'X86', '17': 'X64'}, prefix='/MACHINE:')
    ldflags.extend(self._GetAdditionalLibraryDirectories(
        'VCLinkerTool', config, gyp_to_build_path))
    ld('DelayLoadDLLs', prefix='/DELAYLOAD:')
    out = self.GetOutputName(config, expand_special)
    if out:
      ldflags.append('/OUT:' + out)
    ld('AdditionalOptions', prefix='')
    ld('SubSystem', map={'1': 'CONSOLE', '2': 'WINDOWS'}, prefix='/SUBSYSTEM:')
    ld('LinkIncremental', map={'1': ':NO', '2': ''}, prefix='/INCREMENTAL')
    ld('FixedBaseAddress', map={'1': ':NO', '2': ''}, prefix='/FIXED')
    ld('RandomizedBaseAddress',
        map={'1': ':NO', '2': ''}, prefix='/DYNAMICBASE')
    ld('DataExecutionPrevention',
        map={'1': ':NO', '2': ''}, prefix='/NXCOMPAT')
    ld('OptimizeReferences', map={'1': 'NOREF', '2': 'REF'}, prefix='/OPT:')
    ld('EnableCOMDATFolding', map={'1': 'NOICF', '2': 'ICF'}, prefix='/OPT:')
    ld('LinkTimeCodeGeneration', map={'1': '/LTCG'})
    ld('IgnoreDefaultLibraryNames', prefix='/NODEFAULTLIB:')
    ld('ResourceOnlyDLL', map={'true': '/NOENTRY'})
    # TODO(scottmg): This should sort of be somewhere else (not really a flag).
    ld('AdditionalDependencies', prefix='')
    # TODO(scottmg): These too.
    ldflags.extend(('kernel32.lib', 'user32.lib', 'gdi32.lib', 'winspool.lib',
        'comdlg32.lib', 'advapi32.lib', 'shell32.lib', 'ole32.lib',
        'oleaut32.lib', 'uuid.lib', 'odbc32.lib', 'DelayImp.lib'))

    # If the base address is not specifically controlled, DYNAMICBASE should
    # be on by default.
    base_flags = filter(lambda x: 'DYNAMICBASE' in x or x == '/FIXED',
                        ldflags)
    if not base_flags:
      ldflags.append('/DYNAMICBASE')

    # If the NXCOMPAT flag has not been specified, default to on. Despite the
    # documentation that says this only defaults to on when the subsystem is
    # Vista or greater (which applies to the linker), the IDE defaults it on
    # unless it's explicitly off.
    if not filter(lambda x: 'NXCOMPAT' in x, ldflags):
      ldflags.append('/NXCOMPAT')

    return ldflags

  def IsUseLibraryDependencyInputs(self, config):
    """Returns whether the target should be linked via Use Library Dependency
    Inputs (using component .objs of a given .lib)."""
    uldi = self._Setting(('VCLinkerTool', 'UseLibraryDependencyInputs'), config)
    return uldi == 'true'

  def GetRcflags(self, config, gyp_to_ninja_path):
    """Returns the flags that need to be added to invocations of the resource
    compiler."""
    rcflags = []
    rc = self._GetWrapper(self, self.msvs_settings[config],
        'VCResourceCompilerTool', append=rcflags)
    rc('AdditionalIncludeDirectories', map=gyp_to_ninja_path, prefix='/I')
    rcflags.append('/I' + gyp_to_ninja_path('.'))
    rc('PreprocessorDefinitions', prefix='/d')
    # /l arg must be in hex without leading '0x'
    rc('Culture', prefix='/l', map=lambda x: hex(int(x))[2:])
    return rcflags

  def BuildCygwinBashCommandLine(self, args, path_to_base):
    """Build a command line that runs args via cygwin bash. We assume that all
    incoming paths are in Windows normpath'd form, so they need to be
    converted to posix style for the part of the command line that's passed to
    bash. We also have to do some Visual Studio macro emulation here because
    various rules use magic VS names for things. Also note that rules that
    contain ninja variables cannot be fixed here (for example ${source}), so
    the outer generator needs to make sure that the paths that are written out
    are in posix style, if the command line will be used here."""
    cygwin_dir = os.path.normpath(
        os.path.join(path_to_base, self.msvs_cygwin_dirs[0]))
    cd = ('cd %s' % path_to_base).replace('\\', '/')
    args = [a.replace('\\', '/') for a in args]
    args = ["'%s'" % a.replace("'", "\\'") for a in args]
    bash_cmd = ' '.join(args)
    cmd = (
        'call "%s\\setup_env.bat" && set CYGWIN=nontsec && ' % cygwin_dir +
        'bash -c "%s ; %s"' % (cd, bash_cmd))
    return cmd

  def IsRuleRunUnderCygwin(self, rule):
    """Determine if an action should be run under cygwin. If the variable is
    unset, or set to 1 we use cygwin."""
    return int(rule.get('msvs_cygwin_shell',
                        self.spec.get('msvs_cygwin_shell', 1))) != 0

  def HasExplicitIdlRules(self, spec):
    """Determine if there's an explicit rule for idl files. When there isn't we
    need to generate implicit rules to build MIDL .idl files."""
    for rule in spec.get('rules', []):
      if rule['extension'] == 'idl' and int(rule.get('msvs_external_rule', 0)):
        return True
    return False

  def GetIdlBuildData(self, source, config):
    """Determine the implicit outputs for an idl file. Returns output
    directory, outputs, and variables and flags that are required."""
    midl_get = self._GetWrapper(self, self.msvs_settings[config], 'VCMIDLTool')
    def midl(name, default=None):
      return self.ConvertVSMacros(midl_get(name, default=default))
    tlb = midl('TypeLibraryName', default='${root}.tlb')
    header = midl('HeaderFileName', default='${root}.h')
    dlldata = midl('DLLDataFileName', default='dlldata.c')
    iid = midl('InterfaceIdentifierFileName', default='${root}_i.c')
    proxy = midl('ProxyFileName', default='${root}_p.c')
    # Note that .tlb is not included in the outputs as it is not always
    # generated depending on the content of the input idl file.
    outdir = midl('OutputDirectory', default='')
    output = [header, dlldata, iid, proxy]
    variables = [('tlb', tlb),
                 ('h', header),
                 ('dlldata', dlldata),
                 ('iid', iid),
                 ('proxy', proxy)]
    # TODO(scottmg): Are there configuration settings to set these flags?
    flags = ['/char', 'signed', '/env', 'win32', '/Oicf']
    return outdir, output, variables, flags


def _LanguageMatchesForPch(source_ext, pch_source_ext):
  c_exts = ('.c',)
  cc_exts = ('.cc', '.cxx', '.cpp')
  return ((source_ext in c_exts and pch_source_ext in c_exts) or
          (source_ext in cc_exts and pch_source_ext in cc_exts))

class PrecompiledHeader(object):
  """Helper to generate dependencies and build rules to handle generation of
  precompiled headers. Interface matches the GCH handler in xcode_emulation.py.
  """
  def __init__(self, settings, config, gyp_to_build_path):
    self.settings = settings
    self.config = config
    self.gyp_to_build_path = gyp_to_build_path

  def _PchHeader(self):
    """Get the header that will appear in an #include line for all source
    files."""
    return os.path.split(self.settings.msvs_precompiled_header[self.config])[1]

  def _PchSource(self):
    """Get the source file that is built once to compile the pch data."""
    return self.gyp_to_build_path(
        self.settings.msvs_precompiled_source[self.config])

  def _PchOutput(self):
    """Get the name of the output of the compiled pch data."""
    return '${pchprefix}.' + self._PchHeader() + '.pch'

  def GetObjDependencies(self, sources, objs):
    """Given a list of sources files and the corresponding object files,
    returns a list of the pch files that should be depended upon. The
    additional wrapping in the return value is for interface compatability
    with make.py on Mac, and xcode_emulation.py."""
    if not self._PchHeader():
      return []
    source = self._PchSource()
    assert source
    pch_ext = os.path.splitext(self._PchSource())[1]
    for source in sources:
      if _LanguageMatchesForPch(os.path.splitext(source)[1], pch_ext):
        return [(None, None, self._PchOutput())]
    return []

  def GetPchBuildCommands(self):
    """Returns [(path_to_pch, language_flag, language, header)].
    |path_to_gch| and |header| are relative to the build directory."""
    header = self._PchHeader()
    source = self._PchSource()
    if not source or not header:
      return []
    ext = os.path.splitext(source)[1]
    lang = 'c' if ext == '.c' else 'cc'
    return [(self._PchOutput(), '/Yc' + header, lang, source)]


vs_version = None
def GetVSVersion(generator_flags):
  global vs_version
  if not vs_version:
    vs_version = gyp.MSVSVersion.SelectVisualStudioVersion(
        generator_flags.get('msvs_version', 'auto'))
  return vs_version

def _GetBinaryPath(generator_flags, tool):
  vs = GetVSVersion(generator_flags)
  return ('"' + vs.ToolPath(tool) + '"')

def GetCLPath(generator_flags):
  return _GetBinaryPath(generator_flags, 'cl.exe')

def GetLinkPath(generator_flags):
  return _GetBinaryPath(generator_flags, 'link.exe')

def GetLibPath(generator_flags):
  return _GetBinaryPath(generator_flags, 'lib.exe')

def GetMidlPath(generator_flags):
  return _GetBinaryPath(generator_flags, 'midl.exe')

def GetRCPath(generator_flags):
  return _GetBinaryPath(generator_flags, 'rc.exe')

def GetVsvarsPath(generator_flags):
  vs = GetVSVersion(generator_flags)
  return vs.SetupScript()

def ExpandMacros(string, expansions):
  """Expand $(Variable) per expansions dict. See MsvsSettings.GetVSMacroEnv
  for the canonical way to retrieve a suitable dict."""
  if '$' in string:
    for old, new in expansions.iteritems():
      assert '$(' not in new, new
      string = string.replace(old, new)
  return string
