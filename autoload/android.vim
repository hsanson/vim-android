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

function! android#setCompiler()
  silent! execute("compiler android")
endfunction

function! android#isAndroidCompilerSet()
  if(b:current_compiler == "android")
    return 1
  else
    return 0
  endif
endfunction

""
" Simple heuristic that tries to find the location for the AndroidManifest.xml
" file.
"
" If the g:android_manifest is set then use it as location for the manifest.
"
" If the current opened buffer is the AndroidManifest.xml file and
" if it is then return its absolute path.
"
" Finally try to find the manifest using the findfile function of vim that looks
" recursively inside the current path.
function! android#findManifest()

  if exists('g:android_manifest')
    return g:android_manifest
  endif

  if(expand('%:t') == 'AndroidManifest.xml')
    let g:android_manifest = expand('%:p')
    return g:android_manifest
  endif

  let old_wildignore = &wildignore
  set wildignore+=*/build/*
  let g:android_manifest = findfile("AndroidManifest.xml")
  let &wildignore = old_wildignore
  return g:android_manifest
endfunction

function! android#isAndroidProject()
  return filereadable(android#findManifest())
endfunction

function! android#isGradleProject()
  return android#getBuildType() == "gradle"
endfunction

function! android#isAntProject()
  return android#getBuildType() == "ant"
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

" Try to automagically determine the build type (gradle or ant) giving
" preference to gradle builds. It is possible to override this preference by
" directly setting the g:android_build_type variable to *gradle* or *ant* in
" the vimrc file.
function! android#getBuildType()

  if(exists('g:android_build_type'))
    return g:android_build_type
  endif

  let g:android_build_type = "undefined"

  if ! android#checkAndroidHome()
    return g:android_build_type
  endif

  let l:gradle_cfg_exists = filereadable('build.gradle')
  let l:gradle_bin_exists = executable(gradle#bin())
  let l:ant_cfg_exists = filereadable('build.xml')
  let l:ant_bin_exists = executable(ant#bin())

  if( ! l:gradle_cfg_exists && ! l:ant_cfg_exists )
    call android#loge("Could not find any build.gradle or build.xml file... aborting")
    return g:android_build_type
  endif

  if( l:gradle_cfg_exists && l:gradle_bin_exists )
    let g:android_build_type = "gradle"
    return g:android_build_type
  endif

  if( l:ant_cfg_exists && l:ant_bin_exists )
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

""
" Appends ctags for all referenced libraries used for the Android project. The
" library list is obtained from the project.properties file.
function! android#updateLibraryTags()
  " TODO: Implement this method
endfunction

""
" Create a tags file inside the g:android_sdk_tags folder that includes tags for
" the current project source, the target android sdk source, all library
" dependencies, all xml resource files, etc.
function! android#updateAndroidTags()

  if !executable("ctags")
    call android#logw("updateAndroidTags() failed: ctags tool not found.")
    return 0
  endif

  let l:android_sources = substitute(copy($SRCPATH), ":", " ", "g")
  let l:ctags_cmd = 'ctags --recurse --fields=+l --langdef=XML --langmap=Java:.java,XML:.xml --languages=Java,XML --regex-XML=/id="([a-zA-Z0-9_]+)"/\1/d,definition/  -f '

  if exists("*mkdir")
    let l:basepath = fnamemodify(g:android_sdk_tags, ":h")
    silent! mkdir(l:basepath, "p")
  endif

  if finddir(l:basepath) == ""
    call android#loge("Tags folder " . l:basepath . " does not exists. Create the path or change your g:android_sdk_tags variable to a path that exists.")
    return
  endif

  let l:cmd = l:ctags_cmd . g:android_sdk_tags . " " . l:android_sources

  "if exists('g:loaded_dispatch')
  ""  silent! exe 'Start!' l:cmd
  "else
    call android#logi("Generating android SDK tags (may take a while to finish)" )
    call system(l:cmd)
    call android#logi("  Done!" )
  "endif
endfunction

function! s:compile(action)
  let shellpipe = &shellpipe

  if(android#isGradleProject())
    let &shellpipe = '2>'
  endif

  call android#logi("Compiling " . a:action)
  "if exists('g:loaded_dispatch')
  ""  silent! exe 'Make'
  "else
    execute("silent! make " . a:action)
    redraw!
  "endif

  " Restore previous values
  let &shellpipe = shellpipe
  return s:getErrorCount()
endfunction

" This method returns the number of valid errors in the quickfix window. This
" allows us to check if there are errors after compilation.
function! s:getErrorCount()
  let l:list = deepcopy(getqflist())
  return len(filter(l:list, "v:val['valid'] > 0"))
endfunction

" Try to determine the project package name by reading the AndroidManifest.xml
" file. Returns a string containing the package name or throws and exception if
" not found.
function! android#packageName()
  if ! exists("s:androidPackageName")
    for line in readfile(android#findManifest())
      if line =~ 'package='
        let s:androidPackageName = matchstr(line, '\cpackage=\([''"]\)\zs.\{-}\ze\1')
        if empty("s:androidPackageName")
          throw "Unable to get package name"
        endif
      endif
    endfor
  endif
  return s:androidPackageName
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" High level methods

function! android#clean()

  if(!android#isAndroidCompilerSet())
    throw "Android compiler not set"
  endif

  let l:result = s:compile("clean")

  if(l:result == 0)
    call android#logi("Finished cleaning project")
  else
    call android#logw("Cleaning failed")
  endif
endfunction

function! android#compile(mode)

  if(!android#isAndroidCompilerSet())
    throw "Android compiler not set"
  endif

  if(android#isGradleProject())
    "if mode == 'release' or 'debug' it should add 'assemble' (eg. assembleRelease)
    if (a:mode !~ 'assemble')
      if (a:mode =~ 'release' || a:mode =~ 'debug') 
        let l:result = s:compile('assemble' . android#capitalize(a:mode))
        return
      endif
    endif

    "for 'test' or others it should just execute the command
    let l:result = s:compile(a:mode)
  else
    let l:result = s:compile(a:mode)
  endif

  if(l:result == 0)
    call android#logi("Building finished successfully")
  else
    call android#loge("Building finished with " . l:result . " errors")
  endif
endfunction

function! android#install(mode)

  if(!android#isAndroidCompilerSet())
    throw "Android compiler not set"
  endif

  if(!filereadable(android#getApkPath(a:mode)))
    call android#logw("Android apk file " . android#getApkPath(a:mode) . " not found")
    return
  endif

  let l:mode = a:mode
  let l:devices = adb#devices()

  " If no device found give a warning an exit
  if len(l:devices) == 0
    call android#logw("No android device/emulator found. Skipping install step.")
    return 0
  endif

  " If only one device is found automatically install to it.
  if len(l:devices) == 1
    let l:device = strpart(l:devices[0], 3)
    return adb#install(l:device, a:mode)
  endif

  " If more than one device is found give a list so the user can choose.
  let l:choice = -1

  let l:devices = ["0. All Devices"] + l:devices

  "call add(l:devices, (len(l:devices) + 1) . ". All devices")
  while(l:choice < 0 || l:choice > len(l:devices))
    echom "Select target device"
    call inputsave()
    let l:choice = inputlist(l:devices)
    call inputrestore()
    echo "\n"
  endwhile

  echomsg l:choice

  if l:choice == "0"
    call android#logi("Installing on all devices... (May take some time)")
    call remove(l:devices, 0) " Remove All Devices option
    for device in l:devices
      let l:device = strpart(device, 3)
      let l:result = adb#install(l:device, a:mode)
      if l:result != 0
        call android#logw("Abort installation of all devices")
        return 1
      endif
    endfor
    call android#logi ("Finished installing on the following devices " . join(l:devices, " "))
  else
    let l:option = l:devices[l:choice]
    let l:device = strpart(l:option, 3)
    call android#logi("Installing on " . l:device . " ...")
    let l:res = adb#install(l:device, a:mode)

    if(!l:res)
      call android#logi("Finished installing on " . l:device)
    endif
  endif
endfunction

function! android#uninstall()

  if(!android#isAndroidCompilerSet())
    call android#logw("No android compiler set.")
    return
  endif

  let l:devices = adb#devices()

  " If no device found give a warning an exit
  if len(l:devices) == 0
    call android#logw("No android device/emulator found. Skipping uninstall.")
    return 0
  endif

  " If only one device is found automatically uninstall app from it.
  if len(l:devices) == 1
    let l:device = strpart(l:devices[0], 3)
    call adb#uninstall(l:device)
    call android#logi("Finished uninstalling from device " . l:device)
    return 0
  endif

  " If more than one device is found give a list so the user can choose.
  let l:choice = -1
  let l:devices = ["0. All Devices"] + l:devices
  while(l:choice < 0 || l:choice > len(l:devices))
    echom "Select target device"
    call inputsave()
    let l:choice = inputlist(l:devices)
    call inputrestore()
    echo "\n"
  endwhile

  if l:choice == 0
    call android#logi("Uninstalling from all devices...")
    call remove(l:devices, 0)
    for device in l:devices
      let l:device = strpart(device, 3)
      call adb#uninstall(l:device)
    endfor
    call android#logi ("Finished uninstalling from the following devices " . join(l:devices, " "))
  else
    let l:option = l:devices[l:choice]
    let l:device = strpart(l:option, 3)
    call adb#uninstall(l:device)
    call android#logi ("Finished uninstalling from device " . l:device)
  endif
endfunction

""
" Add the android sdk ctags file to the local tags. This assumes the android
" tags file is located at '~/.vim/tags/android' by default or the value set on
" the g:android_sdk_tags variable if defined.
function! android#setAndroidSdkTags()
  if !exists('g:android_sdk_tags')
    let g:android_sdk_tags = getcwd() . '/.tags'
  endif
  execute 'silent! setlocal ' . 'tags+=' . g:android_sdk_tags
endfunction

function! android#setClassPath()
  call classpath#setClassPath()
endfunction

""
" Try to find out the project name. The resulting apk files will have this name
" as prefix so we need it to install the apk on the devices/emulators.
"
function! android#getProjectName()
  if filereadable('build.xml')
    " If there is a build.xml file (ant build) we can get the project name from
    " it.
    for line in readfile('build.xml')
      if line =~ "project name"
        let s:androidProjectName = matchstr(line, '\cproject name=\([''"]\)\zs.\{-}\ze\1')
      endif
    endfor
  else
    " If there is no build.xml file (gradle build) we use the current directory
    " name as project name.
    "
    " TODO: Using the folder name as project name is not reliable. In gradle
    " 1.11 it is possible to set a different project name in the settings.gradle
    " file. We must add a check here to find that file and if exists then
    " extract the project name from it.
    let s:androidProjectName = fnamemodify(".",":p:h:t")
  endif
  return s:androidProjectName
endfunction

function! android#getApkPath(mode)
  let s:androidApkFile = android#getProjectName() . "-" . a:mode . ".apk"
  let old_wildignore = &wildignore
  let &wildignore = ""
  let s:androidApkPath = findfile(s:androidApkFile, ".**")
  let &wildignore = old_wildignore
  return s:androidApkPath
endfunction

function! android#listDevices()
  let l:devices = adb#devices()
  if len(l:devices) <= 0
    call android#logw("Could not find any android devices or emulators.")
  else
    call android#logi("Android Devices: " . join(l:devices, " "))
  endif
endfunction

" Upcase the first leter of string.
function! android#capitalize(str)
  return substitute(a:str, '\(^.\)', '\u&', 'g')
endfunction

function! android#setupAndroidCommands()
  command! -nargs=1 AndroidBuild call android#compile(<f-args>)
  command! -nargs=1 AndroidInstall call android#install(<f-args>)
  command! AndroidClean call android#clean()
  command! AndroidUninstall call android#uninstall()
  command! AndroidUpdateTags call android#updateAndroidTags()
  command! AndroidDevices call android#listDevices()
endfunction
