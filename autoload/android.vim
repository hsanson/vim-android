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

"" Helper method that returns a list of currently connected and online android
"" devices. This method depends on the android adb tool.
function! s:getDevicesList()
  if !exists('g:android_adb_tool')
    let g:android_adb_tool = g:android_sdk_path . "/platform-tools/adb"
  endif

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
                \%A\ %#[aapt]\ %f:%l:\ %m,%-Z\ %#[javac]\ %p^,%-C%.%#
  silent! make
  redraw!

  let &makeprg = makeprg
  let &errorformat = errorformat
endfunction

function! android#compile(mode)
  call s:callAnt(a:mode)
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
    let $ANDROID_SERIAL = l:device
    call s:callAnt(a:mode, 'install')
    call android#logi("Finished installing on device " . l:device)
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
    call android#logi("Installing on all devices")
    call remove(l:devices, len(l:devices) - 1)
    for device in l:devices
      let l:device = strpart(device, 3)
      let $ANDROID_SERIAL = l:device
      call s:callAnt(a:mode, 'install')
      call android#logi ("Finished installing on the following devices " . join(l:devices, " "))
    endfor
  else
    let l:option = l:devices[l:choice - 1]
    let l:device = strpart(l:option, 3)
    let $ANDROID_SERIAL = l:device
    call s:callAnt(a:mode, 'install')
    echomsg ("Finished installing on device " . l:device)
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
" Try to determine the android target platform and then load the corresponding
" android.jar file into the CLASSPATH environment variable. This way plugins
" like javacomplete should be able to omnicomplete java packages, classes and
" methods.
function! android#setAndroidJarInClassPath()
  if filereadable('project.properties') 
    for line in readfile('project.properties')
      if line =~ 'target='
        let s:androidTargetPlatform = split(line, '=')[1]
        let s:targetAndroidJar = g:android_sdk_path . '/platforms/' . s:androidTargetPlatform . '/android.jar'
        if $CLASSPATH =~ ''
          let $CLASSPATH = s:targetAndroidJar . ':' . $CLASSPATH
        else
          let $CLASSPATH = s:targetAndroidJar
        endif
        break
      endif
    endfor
  end
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
  command! AndroidUpdateProjectTags call android#updateProjectTags()
  command! AndroidUpdateAndroidTags call android#updateAndroidTags()
  command! AndroidUpdateTags call android#updateTags()
  command! AndroidDevices call android#listDevices()
endfunction
