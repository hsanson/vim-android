""
" Function that tries to determine the location of the adb binary.
function! adb#bin()

  if exists('g:android_adb_tool')
    return g:android_adb_tool
  endif

  let g:android_adb_tool = g:android_sdk_path . "/platform-tools/adb"

  if(!executable(g:android_adb_tool))
    if executable("adb")
      let g:android_adb_tool = "adb"
    else
      throw "Unable to find adb tool binary. Ensure you set g:android_sdk_path correctly."
    endif
  endif

  return g:android_adb_tool

endfunction

""
" Get list of connected android devices and emulators
function! adb#devices()

  let l:adb_output = system(adb#bin() . " devices")
  let l:adb_devices = filter(split(l:adb_output, '\n'), 'v:val =~ "device$"')
  let l:adb_devices_sorted = sort(copy(l:adb_devices), "s:sortFunc")
  let l:devices = map(l:adb_devices_sorted, 'v:key + 1 . ". " . substitute(v:val, "\tdevice$", "", "")')

  "call android#logi(len(l:devices) . "  Devices " . join(l:devices, " || "))

  return l:devices
endfunction

""
" Installs android package from device
function! adb#install(device, mode)
  let l:cmd = adb#bin() . ' -s ' . a:device . ' install -r ' . android#getApkPath(a:mode)
  "call android#logi("Installing " . android#getApkPath(a:mode) . " to " . a:device . " (wait...)")
  let l:output = system(l:cmd)
  redraw!
  let l:success = matchstr(l:output, 'Success')
  if empty(l:success)
    let l:errormsg = matchstr(l:output, '\cFailure \[\zs.\{-}\ze\]')
    call android#loge("Installation failed on " . a:device . " with error " . l:errormsg)
    return 1
  else
    "call android#logi("Installation finished on " . a:device)
    return 0
  endif
endfunction

""
" Uninstall android package from device
function! adb#uninstall(device)
  call android#logi("Uninstalling " . android#packageName() . " from " . a:device)
  let l:cmd = adb#bin() . ' -s ' . a:device . ' uninstall ' . android#packageName()
  execute "silent !" . l:cmd
  redraw!
endfunction

""
" Helper method to sort devices list
function! s:sortFunc(i1, i2)
  return tolower(a:i1) == tolower(a:i2) ? 0 : tolower(a:i1) > tolower(a:i2) ? 1 : -1
endfunction

