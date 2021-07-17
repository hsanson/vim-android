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

function! android#glyph()

  if !exists('g:gradle_glyph_android')
    let g:gradle_glyph_android = "A"
  endif

  return g:gradle_glyph_android
endfunction

" If there is a target sdk version defined it means the project is an android
" project.
function! android#isAndroidProject()
  return filereadable(android#manifestFile()) && android#checkAndroidHome()
endfunction

" Tries to determine the location of the AndroidManifest.xml file relative to
" the location of the build.gradle file. Since the findfile() call can take a
" long time to finish and we call this method several times it caches the
" results in a script variable.
function! s:findManifestFile()
  let l:file = findfile("AndroidManifest.xml", gradle#findRoot() . "/**3")
  return copy(fnamemodify(l:file, ":p"))
endfunction

function! android#manifestFile() abort
  return cache#get(gradle#key(gradle#findGradleFile()), 'manifest', s:findManifestFile())
endfunction

function! android#homePath()

  if exists('$ANDROID_HOME')
    let g:android_sdk_path = $ANDROID_HOME
  endif

  if exists('g:android_sdk_path')
    return g:android_sdk_path
  endif

  let g:android_sdk_path = "$HOME/android-sdk"

  return g:android_sdk_path
endfunction

" Function returns the absolute path of the newest build-tools installed inside
" android home directory.
function! android#buildToolsPath()
  return reverse(sort(globpath(android#homePath(), 'build-tools/*', v:true, v:true)))[0]
endfunction

function! android#checkAndroidHome()
  if finddir(android#homePath()) == ""
    return 0
  endif
  return 1
endfunction

" Compatibility method to run android build commands. If the passed command is
" build or debug it is converted to assembleBuild and assembleDebug before
" passing it to gradle.
function! android#compile(...)

  if(a:0 == 0)
    let l:mode = "build"
    call gradle#compile(l:mode)
  elseif(a:0 == 1 && a:1 == "debug")
    let l:mode = 'assemble' . android#capitalize(a:1)
    call gradle#compile(l:mode)
  elseif(a:0 == 1 && a:1 == "release")
    let l:mode = 'assemble' . android#capitalize(a:1)
    call gradle#compile(l:mode)
  else
    call call('gradle#compile', a:000)
  endif

endfunction

function! android#install(mode)

  let l:devices = adb#selectDevice()

  for l:device in l:devices
    call android#logi("Install " . a:mode . " " . l:device)
    let l:result = gradle#install(l:device, a:mode)
    if (l:result[0] > 0) || (l:result[1] > 0)
      call android#logi("Install failed")
      return
    else
      call android#logi ("")
    endif
  endfor
endfunction


function! android#buildremotedebug()
  call android#logi('Build Debug on Remote') 
  let l:cmd = gradle#bin() . ' assembleDebug ' 
 " execute '!' . l:cmd
 let winid = bufwinid('BuildOutput')
  if winid > 0
 call win_gotoid(winid)	  
  bw! "BuildOutput"
  endif
 execute 'new BuildOutput | read ! ' . l:cmd 
 " redraw!
endfunction

function! android#buildremoterelease()
  call android#logi('Build Release on Remote') 
  let l:cmd = gradle#bin() . ' assemble ' 
  " execute '!' . l:cmd
 let winid = bufwinid('BuildOutput')
  if winid > 0
 call win_gotoid(winid)	  
  bw! "BuildOutput"
  endif
  execute 'new BuildOutput | read ! ' . l:cmd
endfunction

function! android#launch(mode)

  let l:devices = adb#selectDevice()

  let l:gradleResult = gradle#build(a:mode)

  if (l:gradleResult[0] > 0) || (l:gradleResult[1] > 0)
    call android#logi("Could not build APK. Launch failed")
    return
  endif

  let l:apk = system('find $(pwd)/*/build/** -name "app-' . a:mode . '.apk" | tr "\n" " " | tr "//" "/"')

  if empty(l:apk)
    call android#logi("Could not find APK. Install/Launch failed")
    return
  endif

 let l:mainId = system(aapt#bin() . ' dump packagename ' . l:apk . ' | sed "s/$/ 1/" ')

  for l:device in l:devices
    call android#logi("Install and Launch " . a:mode . " " . l:device)
    let l:result = adb#install(l:device, l:apk)
    if (l:result[0] > 0) || (l:result[1] > 0)
      call android#logi("Install/Launch failed")
      return
    else
      call android#logi('Main ' . l:mainId . '' )
       let l:launchResult = adb#launch(l:device, l:mainId)
      if (l:launchResult[0] > 0) || (l:launchResult[1] > 0)
        call android#logi("Launch failed")
        return
      else
        call android#logi("")
      endif
    endif
  endfor
endfunction

function! android#uninstall(mode)

  let l:devices = adb#selectDevice()

  for l:device in l:devices
    call android#logi("Uninstall " . a:mode . " " . l:device)
    let l:result = gradle#uninstall(l:device, a:mode)
    if (l:result[0] > 0) || (l:result[1] > 0)
      call android#logi("Uninstall failed")
      return
    else
      call android#logi ("")
    endif
  endfor
endfunction

" Find the adroid sdk srouce files for the target sdk version.
function! android#targetSrcPath()
  let l:targetSrc = android#homePath() . '/sources/' . android#targetVersion() . '/'
  if isdirectory(l:targetSrc)
    return targetSrc
  endif
endfunction

function! android#getProjectJar()
  let l:path = gradle#findRoot() . '/build/intermediates/classes/debug'
  let l:local = fnamemodify(l:path, ':p')
  if isdirectory(l:local)
    return l:local
  else
    return "."
  endif
endfunction

function! android#targetVersion()
  return gradle#targetVersion()
endfunction

function! android#getGradleTargetJar()


  let l:targetJar = android#homePath() . '/platforms/' . android#targetVersion() . "/android.jar"

  return l:targetJar
endfunction

function! android#getSdkJar()
  return cache#get(gradle#key(gradle#findGradleFile()), 'targetJar', android#getGradleTargetJar())
endfunction

" Return array of android dependency classpath.
function! android#classPaths()

  let l:paths = []

  if ! android#isAndroidProject()
    return l:paths 
  endif

  let l:projectJar = android#getProjectJar()

  if len(l:projectJar) > 0
    call add(l:paths, l:projectJar)
  endif

  let l:targetJar = android#getSdkJar()
  if len(l:targetJar) > 0
    call add(l:paths, l:targetJar)
  endif

  return l:paths
endfunction

" Return array of android source paths.
function! android#sourcePaths()

  let l:paths = []

  if ! android#isAndroidProject()
    return l:paths 
  endif

  let l:targetSrc = android#targetSrcPath()

  if len(l:targetSrc) > 0
    call add(l:paths, l:targetSrc)
  endif

  return l:paths
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

""
" Find android emulator binary
function! android#emulatorbin()

  if exists('g:android_emulator')
    return g:android_emulator
  endif

  let g:android_emulator = android#homePath() . '/emulator/emulator'

  if(!executable(g:android_emulator))
    if executable('emulator')
      let g:android_emulator = 'emulator'
    else
      throw 'Unable to find android emulator binary. Ensure you set g:android_sdk_path correctly.'
    endif
  endif

  return g:android_emulator
endfunction

""
" List AVD emulators
function! android#avds()

  let l:avd_output = split(system(android#emulatorbin() . ' -list-avds'))
  let l:avd = map(l:avd_output, 'v:key+1 . ". " . v:val')

  "call android#logi(len(l:devices) . "  Devices " . join(l:devices, " || "))

  return l:avd
endfunction

function! android#emulator()

  let l:avds = extend(['0. Cancel'], android#avds())

  " There are no avds defined
  if len(l:avds) == 0
    call android#logw('No android emulator defined')
    return 0
  endif

  let l:choice = -1

  while(l:choice < 0 || l:choice >= len(l:avds))
    echom 'Select target device'
    call inputsave()
    let l:choice = inputlist(l:avds)
    call inputrestore()
    echo "\n"
  endwhile

  if l:choice <= 0
    redraw!
    return 0
  endif

  let l:option = l:avds[l:choice]
  let l:avd = strpart(l:option, 3)

  execute 'silent !' . android#emulatorbin() . ' -avd ' . l:avd . ' 2>/dev/null  &'
  redraw!

endfunction

function! android#setupAndroidCommands()
  if android#checkAndroidHome()
    command! -nargs=+ Android call android#compile(<f-args>)
    command!  AndroidMirakleDebug call android#buildremotedebug()
    command!  AndroidMirakleRelease call android#buildremoterelease()
    command! -nargs=? AndroidBuild call android#compile(<f-args>)
    command! -nargs=1 AndroidInstall call android#install(<f-args>)
    command! -nargs=1 AndroidUninstall call android#uninstall(<f-args>)
    command! -nargs=1 AndroidLaunch call android#launch(<f-args>)
    command! AndroidDevices call android#listDevices()
    command! AndroidEmulator call android#emulator()
  else
    command! -nargs=? Android call android#loge("Could not find android SDK. Ensure the g:android_sdk_path variable or ANDROID_HOME env variable are set and correct.")
  endif
endfunction

