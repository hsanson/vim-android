function! android#logi(msg)
  redraw
  echomsg "vim-android: " . a:msg
endfunction

function! android#logw(msg)
  echohl warningmsg
  echo "vim-android: " . a:msg
  echohl normal
endfunction

function! android#loge(msg)
  echohl errormsg
  echo "vim-android: " . a:msg
  echohl normal
endfunction

function! android#isAndroidProject()
  return filereadable("AndroidManifest.xml")
endfunction

function! android#isGradleProject()
  return g:android_build_type == "gradle"
endfunction

function! android#isAntProject()
  return g:android_build_type == "ant"
endfunction

function! android#checkAndroidHome()
  if exists("g:android_sdk_path") && finddir(g:android_sdk_path) != ""
    let $ANDROID_HOME=g:android_sdk_path
  elseif exists("$ANDROID_HOME") && finddir($ANDROID_HOME) != ""
    let g:android_sdk_path = $ANDROID_HOME
  else
    call android#loge("Could not find android SDK. Ensure the g:android_sdk_path variable or ANDROID_HOME env variable are set and correct.")
    return 0
  endif
  return 1
endfunction

" Helper method that tries to find out if the project is build using Ant or
" Gradle.
function! android#findProjectType()
  if ! android#checkAndroidHome()
    return
  endif

  let g:android_build_type = "undefined"
  let l:gradle_cfg_exists = filereadable('build.gradle')
  let l:gradle_bin_exists = executable(s:getGradleBin())
  let l:ant_cfg_exists = filereadable('build.xml')
  let l:ant_bin_exists = executable('ant')

  if( ! l:gradle_cfg_exists && ! l:ant_cfg_exists )
    call android#loge("Could not find any build.gradle or build.xml file... aborting")
    return g:android_build_type
  endif

  if( l:gradle_cfg_exists && l:gradle_bin_exists )
    call android#logi("Found gradle build system")
    let g:android_build_type = "gradle"
    return g:android_build_type
  endif

  if( l:ant_cfg_exists && l:ant_bin_exists )
    call android#logi("Found ant build system")
    let g:android_build_type = "ant"
    return g:android_build_type
  endif

  if( l:gradle_cfg_exists && ! l:gradle_bin_exists )
    call android#loge("Found build.gradle file but there is no gradle binary available. Set the g:gradle_path varible to point to your gradle installation.")
  endif

  if( l:ant_cfg_exists && ! l:ant_bin_exists )
    call android#loge("Found build.ant file but there is not ant binary available. Make sure you installed ant and ant-optional packages on you machine.")
  endif

  return g:android_build_type
endfunction

function! android#hasVimProc(...)
  try
    call vimproc#version()
    let l:exists_vimproc = 1
  catch
    let l:exists_vimproc = 0
  endtry
  return l:exists_vimproc
endfunction

""
" Calling this methods will create a ctags file from the android source and
" included libraries into the projects root folder. This tag can be used then
" to auto-complete and navigate the project source code.
function! android#updateProjectTags()
  if !android#hasVimProc()
    call android#logw("updateProjecTags() failed: required VimProc plugin not found.")
    return 0
  endif

  if !executable("ctags")
    call android#logw("updateProjectTags() failed: required ctag binary not found.")
    return 0
  endif

  if !android#isAndroidProject()
    call android#logw("updateProjectTags() failed: pwd must be on the android project root.")
    return 0
  endif

  if !executable("ctags")
    call android#logw(updateProjectTags() failed: could not find ctags executable")
    return 0
  endif

  let l:project_path = getcwd()
  let l:ctags_args = " --recurse --langmap=Java:.java --languages=Java --verbose -f "
  let l:ctags_cmd = vimproc#get_command_name('ctags') . l:ctags_args

  try
    let l:ps_cmd = vimproc#get_command_name('ps')
    let l:cmd = l:ps_cmd . " -C ctags || " .  l:ctags_cmd . l:project_path  . "/.tags " . l:project_path . "/src"
  catch
    let l:cmd = l:ctags_cmd . l:project_pat . "/.tags " . l:project_path . "/src"
  endtry

  call android#logi("Generating project tags (may take a while to finish)" )
  call vimproc#system(l:cmd)
  call android#logi("Done!" )
endfunction

""
" Appends ctags for all referenced libraries used for the Android project. The
" library list is obtained from the project.properties file.
function! android#updateLibraryTags()
  " TODO: Implement this method
endfunction

""
" Calling this methods will create a ctags file from the Android SDK sources
" and store it in the path defined by the g:android_sdk_tags variable. This
" function only works if the VimProc plugin is installed and working.
function! android#updateAndroidTags()
  if !android#hasVimProc()
    call android#logw("updateAndroidTags() failed: required VimProc plugin not found.")
    return 0
  endif

  let l:ctags_bin = vimproc#get_command_name('ctags')

  if !executable(l:ctags_bin)
    call android#logw("updateAndroidTags() failed: could not find ctags executable")
    return 0
  endif

  let l:android_sources = g:android_sdk_path . "/sources"
  let l:ctags_args = " --recurse --langmap=Java:.java --languages=Java --verbose -f "
  let l:ctags_cmd = l:ctags_bin . l:ctags_args

  if exists("*mkdir")
    let l:basepath = fnamemodify(g:android_sdk_tags, ":h")
    silent! mkdir(l:basepath, "p")
  endif

  if finddir(l:basepath) == ""
    call android#loge("Tags folder " . l:basepath . " does not exists. Create the path or change your g:android_sdk_tags variable to a path that exists.")
    return
  endif

  try
    let l:ps_cmd = vimproc#get_command_name('ps')
    let l:cmd = l:ps_cmd . " -C ctags || " .  l:ctags_cmd . g:android_sdk_tags . " " . l:android_sources
  catch
    let l:cmd = l:ctags_cmd . g:android_sdk_tags . " " . l:android_sources
  endtry

  call android#logi("Generating android SDK tags (may take a while to finish)" )
  call vimproc#system(l:cmd)
  call android#logi("  Done!" )
endfunction

function! android#updateTags()
  call android#updateAndroidTags()
  call android#updateProjectTags()
  call android#updateLibraryTags()
endfunction

function! s:sortFunc(i1, i2)
  return tolower(a:i1) == tolower(a:i2) ? 0 : tolower(a:i1) > tolower(a:i2) ? 1 : -1
endfunction

function! s:getGradleBin()
  if !exists('g:gradle_path')
    let g:gradle_path = $GRADLE_HOME
  endif
  let g:gradle_tool = g:gradle_path . "/bin/gradle"
  return g:gradle_tool
endfunction

function! s:getAdbBin()
  if !exists('g:android_adb_tool')
    let g:android_adb_tool = g:android_sdk_path . "/platform-tools/adb"
  endif
  return g:android_adb_tool
endfunction

"" Helper method that returns a list of currently connected and online android
"" devices. This method depends on the android adb tool.
function! s:getDevicesList()
  call s:getAdbBin()

  if !executable(g:android_adb_tool)
    call android#loge("Android adb tool could not be found. Set g:android_adb_tool to point to the location of the adb tool")
    return []
  endif

  let l:adb_output = system(g:android_adb_tool . " devices")
  let l:adb_devices = filter(split(l:adb_output, '\n'), 'v:val =~ "device$"')
  let l:adb_devices_sorted = sort(copy(l:adb_devices), "s:sortFunc")
  let l:devices = map(l:adb_devices_sorted, 'v:key + 1 . ". " . substitute(v:val, "\tdevice$", "", "")')

  "call android#logi(len(l:devices) . "  Devices " . join(l:devices, " || "))

  return l:devices
endfunction

function! s:callClean()
  if android#isGradleProject()
    call android#logi("Cleaning gradle project")
    call s:callGradleClean()
    call android#logi("Finished cleaning project")
  elseif android#isAntProject()
    call android#logi("Cleaning ant project")
    call s:callAnt("clean")
    call android#logi("Finished cleaning project")
  else
    call android#loge("Could find a gradle nor an ant project")
  endif
endfunction

function! s:callBuild(mode)
  if android#isGradleProject()
    call android#logi("Building gradle project")
    return s:callGradleBuild(a:mode)
  elseif android#isAntProject()
    call android#logi("Building ant project")
    return s:callAnt(a:mode)
  else
    call android#loge("Could find a gradle nor an ant project")
  endif
endfunction

function! s:callGradleBuild(mode)
  return s:callGradle("assemble" . s:capitalize(a:mode))
endfunction

function! s:callGradleClean()
  return s:callGradle("clean")
endfunction

function! s:callGradle(action)
  let makeprg = &makeprg
  let errorformat = &errorformat
  let makeef = &makeef

  " Modify the shellpipe to save only stderr to the makeef file. If we do
  " not do this then the output file will have the stdout and stderr messages
  " interleaved making it impossible for errorformat to parse the error
  " messages.
  let shellpipe = &shellpipe
  let &shellpipe='2>'

  let &makeprg = g:gradle_tool . " " . a:action

  set errorformat=%f:%l:\ %m,
        \%A%f:%l:\ %m,%-Z%p^,%-C%.%#

  silent! make
  redraw!

  " Restore previous values
  let &makeprg = makeprg
  let &errorformat = errorformat
  let &shellpipe = shellpipe
  return s:getErrorCount()
endfunction

function! s:callAnt(mode)
  let makeprg = &makeprg
  let errorformat = &errorformat

  let &makeprg = 'ant -find build.xml ' . a:mode

  set errorformat=\ %#[javac]\ %#%f:%l:%c:%*\\d:%*\\d:\ %t%[%^:]%#:%m,
                \%A\ %#[javac]\ %f:%l:\ %m,
                \%A\ %#[aapt]\ %f:%l:\ %m,%-Z\ %#[javac]\ %p^,%-C%.%#,
                \%A\ %#[exec]\ Failure\ [%m]

  silent! make
  redraw!

  let &makeprg = makeprg
  let &errorformat = errorformat
  return s:getErrorCount()
endfunction

" This method returns the number of valid errors in the quickfix window. This
" allows us to check if there are errors after compilation.
function! s:getErrorCount()
  let l:list = deepcopy(getqflist())
  return len(filter(l:list, "v:val['valid'] > 0"))
endfunction

function! s:callInstall(mode, device)
  if android#isGradleProject()
    return s:callInstallGradle(a:mode, a:device)
  elseif android#isAntProject()
    return s:callInstallAnt(a:mode, a:device)
  else
    call android#loge("Unknown build system")
  endif
endfunction

function! s:capitalize(str)
  return substitute(a:str, '\(^.\)', '\u&', 'g')
endfunction

function! s:callInstallGradle(mode, device)
  let l:cmd = "ANDROID_SERIAL=" . a:device . " " . s:getGradleBin() . ' install' . s:capitalize(a:mode)
  call android#logi("Installing " . a:mode . " to " . a:device . " (wait...)")
  let l:output = system(l:cmd)
  redraw!
  let l:failure = matchstr(l:output, "Failure")
  if empty(l:failure)
    call android#logi("Installation finished on " . a:device)
    return 0
  else
    let l:errormsg = matchstr(l:output, '\cFailure \[\zs.\{-}\ze\]')
    call android#loge("Installation failed on " . a:device . " with error " . l:errormsg)
    return 1
  endif
endfunction

function! s:callInstallAnt(mode, device)
  let l:cmd = s:getAdbBin() . ' -s ' . a:device . ' install -r ' . android#getApkPath(a:mode)
  call android#logi("Installing " . android#getApkPath(a:mode) . " to " . a:device . " (wait...)")
  let l:output = system(l:cmd)
  redraw!
  let l:success = matchstr(l:output, 'Success')
  if empty(l:success)
    let l:errormsg = matchstr(l:output, '\cFailure \[\zs.\{-}\ze\]')
    call android#loge("Installation failed on " . a:device . " with error " . l:errormsg)
    return 1
  else
    call android#logi("Installation finished on " . a:device)
    return 0
  endif
endfunction

function! s:androidPackageName()
  if ! exists(s:androidPackageName)
    if filereadable('AndroidManifest.xml')
      for line in readfile('AndroidManifest.xml')
        if line =~ 'package='
          let s:androidPackageName = matchstr(line, '\cpackage=\([''"]\)\zs.\{-}\ze\1')
          if empty(s:androidPackageName)
            throw "Unable to get package name"
          endif
        endif
      endfor
    endif
  endif
  return s:androidPackageName
endfunction

function! s:callUninstall(device)
  call android#logi("Uninstalling " . s:androidPackageName() . " from " . a:device)
  let l:cmd = s:getAdbBin() .' -s ' . a:device . ' uninstall ' . s:androidPackageName()
  execute "silent !" . l:cmd
  redraw!
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" High level methods

function! android#clean()
  if(android#findProjectType() == "undefined")
    return
  endif
  return s:callClean()
endfunction

function! android#compile(mode)
  if(android#findProjectType() == "undefined")
    return
  endif

  let l:result = s:callBuild(a:mode)
  if(l:result == 0)
    call android#logi("Building finished successfully")
  else
    call android#loge("Building finished with " . l:result . " errors")
  endif
endfunction

function! android#install(mode)
  if(android#findProjectType() == "undefined")
    return
  endif
  let l:mode = a:mode
  let l:devices = s:getDevicesList()

  " If no device found give a warning an exit
  if len(l:devices) == 0
    call s:callBuild(a:mode)
    call android#logw("No android device/emulator found. Skipping install step.")
    return 0
  endif

  " If only one device is found automatically install to it.
  if len(l:devices) == 1
    let l:device = strpart(l:devices[0], 3)
    let l:result = s:callBuild(a:mode)
    if(l:result == 0)
      call android#logi("Build finished without issues...")
      return s:callInstall(a:mode, l:device)
    else
      call android#loge("Compilation failed... Skip installing step")
      return l:result
    endif
  endif

  " If more than one device is found give a list so the user can choose.
  let l:choice = -1
  call add(l:devices, (len(l:devices) + 1) . ". All devices")
  while(l:choice < 0 || l:choice > len(l:devices))
    echom "Select target device"
    call inputsave()
    let l:choice = inputlist(l:devices)
    call inputrestore()
    echo "\n"
  endwhile

  " Zero means cancel the operation
  if l:choice == 0
    return 0
  endif

  let l:result = s:callBuild(a:mode)
  if(l:result != 0)
    call android#loge("Compilation failed... Skip installing step")
    return l:result
  endif

  call android#logi("Build finished without issues...")

  if l:choice == len(l:devices)
    call android#logi("Installing on all devices")
    call remove(l:devices, len(l:devices) - 1)
    for device in l:devices
      let l:device = strpart(device, 3)
      let l:result = s:callInstall(a:mode, l:device)
      if l:result != 0
        call android#logw("Abort installtion of all devices")
        return 1
      endif
    endfor
    call android#logi ("Finished installing on the following devices " . join(l:devices, " "))
  else
    let l:option = l:devices[l:choice - 1]
    let l:device = strpart(l:option, 3)
    call s:callInstall(a:mode, l:device)
  endif
endfunction

function! android#uninstall()
  if(android#findProjectType() == "undefined")
    return
  endif

  let l:devices = s:getDevicesList()

  " If no device found give a warning an exit
  if len(l:devices) == 0
    call android#logw("No android device/emulator found. Skipping uninstall.")
    return 0
  endif

  " If only one device is found automatically uninstall app from it.
  if len(l:devices) == 1
    let l:device = strpart(l:devices[0], 3)
    call s:callUninstall(l:device)
    call android#logi("Finished uninstalling from device " . l:device)
    return 0
  endif

  " If more than one device is found give a list so the user can choose.
  let l:choice = -1
  call add(l:devices, (len(l:devices) + 1) . ". All devices")
  while(l:choice < 0 || l:choice > len(l:devices))
    echom "Select target device"
    call inputsave()
    let l:choice = inputlist(l:devices)
    call inputrestore()
    echo "\n"
  endwhile

  " Zero means cancel the operation
  if l:choice == 0
    return 0
  endif

  if l:choice == len(l:devices)
    call android#logi("Uninstalling from all devices")
    call remove(l:devices, len(l:devices) - 1)
    for device in l:devices
      let l:device = strpart(device, 3)
      call s:callUninstall(l:device)
      call android#logi ("Finished uninstalling from device " . l:device)
    endfor
    call android#logi ("Finished uninstalling from the following devices " . join(l:devices, " "))
  else
    let l:option = l:devices[l:choice - 1]
    let l:device = strpart(l:option, 3)
    call s:callUninstall(l:device)
    call android#logi ("Finished uninstalling from device " . l:device)
  endif
endfunction

""
" Add the android sdk ctags file to the local tags. This assumes the android
" tags file is located at '~/.vim/tags/android' by default or the value set on
" the g:android_sdk_tags variable if defined.
function! android#setAndroidSdkTags()
  if !exists('g:android_sdk_tags')
    let g:android_sdk_tags = '~/.vim/tags/android'
  endif
  execute 'setlocal'  'tags+=' . g:android_sdk_tags
endfunction

function! android#setClassPath()
  call classpath#setClassPath()
endfunction

function! android#getProjectName()
  " Now try to find out the project name and the apk file names for release and
  " debug.
  if filereadable('build.xml')
    for line in readfile('build.xml')
      if line =~ "project name"
        let s:androidProjectName = matchstr(line, '\cproject name=\([''"]\)\zs.\{-}\ze\1')
      endif
    endfor
  end
  return s:androidProjectName
endfunction

function! android#getDebugApkPath()
  let s:androidDebugApkPath = "bin/" . android#getProjectName() . "-debug.apk"
  return s:androidDebugApkPath
endfunction

function! android#getReleaseApkPath()
  let s:androidReleaseApkPath = "bin/" . android#getProjectName() . "-release.apk"
  return s:androidReleaseApkPath
endfunction

function! android#getApkPath(mode)
  if a:mode == "release"
    return android#getReleaseApkPath()
  else
    return android#getDebugApkPath()
  endif
endfunction

function! android#listDevices()
  let l:devices = s:getDevicesList()
  if len(l:devices) <= 0
    call android#logw("Could not find any android devices or emulators.")
  else
    call android#logi("Android Devices: " . join(l:devices, " "))
  endif
endfunction

function! android#setupAndroidCommands()
  command! -nargs=1 AndroidBuild call android#compile(<f-args>)
  command! -nargs=1 AndroidInstall call android#install(<f-args>)
  command! AndroidClean call android#clean()
  command! AndroidUninstall call android#uninstall()
  command! AndroidUpdateProjectTags call android#updateProjectTags()
  command! AndroidUpdateAndroidTags call android#updateAndroidTags()
  command! AndroidUpdateTags call android#updateTags()
  command! AndroidDevices call android#listDevices()
endfunction
