function! android#logi(msg)
  redraw
  echomsg a:msg
endfunction

function! android#logw(msg)
  echohl warningmsg
  echo a:msg
  echohl normal
endfunction

function! android#loge(msg)
  echohl errormsg
  echo a:msg
  echohl normal
endfunction

function! android#isAndroidProject()
  if glob('AndroidManifest.xml') =~ ''
    return 1
  else
    return 0
  endif
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
    call android#logw("updateProjecTags() failed: required VimProc plugin not found.")
    return 0
  endif

  if !executable("ctags")
    call android#logw(updateProjectTags() failed: could not find ctags executable")
    return 0
  endif

  let l:android_sources = g:android_sdk_path . "/sources"
  let l:ctags_args = " --recurse --langmap=Java:.java --languages=Java --verbose -f "
  let l:ctags_cmd = vimproc#get_command_name('ctags') . l:ctags_args

  try
    let l:ps_cmd = vimproc#get_command_name('ps')
    let l:cmd = l:ps_cmd . " -C ctags || " .  l:ctags_cmd . g:android_sdk_tags . " " . l:android_sources
  catch
    let l:cmd = l:ctags_cmd . g:android_sdk_tags . " " . l:android_sources
  endtry

  call android#logi("Generating android SDK tags (may take a while to finish)" )
  call vimproc#system(l:cmd)
  call android#logi("Done!" )
endfunction

function! android#updateTags()
  call android#updateAndroidTags()
  call android#updateProjectTags()
  call android#updateLibraryTags()
endfunction

function! s:sortFunc(i1, i2)
  return tolower(a:i1) == tolower(a:i2) ? 0 : tolower(a:i1) > tolower(a:i2) ? 1 : -1
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

function! s:callAnt(...)
  let makeprg = &makeprg
  let errorformat = &errorformat

  if index(a:000, '-f') == -1
    let &makeprg = 'ant -find build.xml ' . join(a:000)
  else
    let &makeprg = 'ant ' . join(a:000)
  endif

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

function! s:callUninstall(device)
  call android#logi("Uninstalling " . s:androidPackageName . " from " . a:device)
  let l:cmd = 'adb -s ' . a:device . ' uninstall ' . s:androidPackageName
  execute "silent !" . l:cmd
  redraw!
endfunction

function! android#compile(mode)
  return s:callAnt(a:mode)
endfunction

function! android#install(mode)
  let l:mode = a:mode
  let l:devices = s:getDevicesList()

  " If no device found give a warning an exit
  if len(l:devices) == 0
    call s:callAnt(a:mode)
    call android#logw("No android device/emulator found. Skipping install step.")
    return 0
  endif

  " If only one device is found automatically install to it.
  if len(l:devices) == 1
    let l:device = strpart(l:devices[0], 3)
    let l:result = s:callAnt(a:mode)
    if(l:result == 0)
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

  let l:result = s:callAnt(a:mode)
  if(l:result != 0)
    call android#loge("Compilation failed... Skip installing step")
    return l:result
  endif

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

""
" Update the CLASSPATH environment variable to include all classes related to
" the current Android project. This allows other plugins like javacomplete to
" find the classes and methods for auto-completion.
function! android#setAndroidJarInClassPath()
  let s:paths = []

  " Obtain a list of current paths in the $CLASSPATH
  let s:oldpaths = split($CLASSPATH, ':')

  " Add our project classes path
  let s:local='./bin/classes'
  if index(s:oldpaths, s:local) == -1
    call add(s:paths, s:local)
  endif

  " Next find out if the project uses external libraries. If so add the
  " corresponding jars.
  if filereadable('project.properties') 
    for line in readfile('project.properties')
      if line =~ 'android.library.reference'
        let s:path = split(line, '=')[1]
        let s:referenceJar = s:path . "/bin/classes.jar"
        if index(s:oldpaths, s:referenceJar) == -1
          call add(s:paths, s:referenceJar)
        endif
      endif
    endfor
  end

  " Also include any jar files inside the project libs directory.
  let s:libs='./libs/*'
  if index(s:oldpaths, s:libs) == -1
    call add(s:paths, s:libs)
  endif

  " Try to find the android target SDK and corresponding jar path and the
  " package name.
  if filereadable('AndroidManifest.xml') 
    for line in readfile('AndroidManifest.xml')
      if line =~ 'android:targetSdkVersion='
        let s:androidTarget = matchstr(line, '\candroid:targetSdkVersion=\([''"]\)\zs.\{-}\ze\1')
        let s:androidTargetPlatform = 'android-' . s:androidTarget
        let s:targetAndroidJar = g:android_sdk_path . '/platforms/' . s:androidTargetPlatform . '/android.jar'
        if index(s:oldpaths, s:targetAndroidJar) == -1
          call add(s:paths, s:targetAndroidJar)
        endif
        break
      endif

      if line =~ 'package='
        let s:androidPackageName = matchstr(line, '\cpackage=\([''"]\)\zs.\{-}\ze\1')
        if empty(s:androidPackageName)
          throw "Unable to get package name"
        endif
      endif
    endfor
  end

  " Finally add any other paths already defined in the $CLASSPATH
  call extend(s:paths, s:oldpaths)

  let $CLASSPATH = join(copy(s:paths), ':')
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
  command! AndroidDebug call android#compile("debug")
  command! AndroidRelease call android#compile("release")
  command! AndroidDebugInstall call android#install("debug")
  command! AndroidReleaseInstall call android#install("release")
  command! AndroidClean call android#compile("clean")
  command! AndroidUninstall call android#uninstall()
  command! AndroidUpdateProjectTags call android#updateProjectTags()
  command! AndroidUpdateAndroidTags call android#updateAndroidTags()
  command! AndroidUpdateTags call android#updateTags()
  command! AndroidDevices call android#listDevices()
endfunction
