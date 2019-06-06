""
" Function that tries to determine the location of the adb binary.
function! adb#bin()

  if exists('g:android_adb_tool')
    return g:android_adb_tool
  endif

  let g:android_adb_tool = g:android_sdk_path . '/platform-tools/adb'

  if(!executable(g:android_adb_tool))
    if executable('adb')
      let g:android_adb_tool = 'adb'
    else
      let g:android_adb_tool = '/bin/false'
    endif
  endif

  return g:android_adb_tool

endfunction

""
" Get list of connected android devices and emulators
function! adb#devices()

  let l:adb_output = split(system(adb#bin() . ' devices'), '\n')
  let l:adb_devices = []

  for line in l:adb_output
    let l:adb_device = matchlist(line, '\v^(.+)\s+device$')
    if !empty(l:adb_device)
      let l:serial = s:trim(copy(l:adb_device[1]))
      let l:info   = adb#getDeviceInfo(l:serial)
      call add(l:adb_devices, l:info)
    endif
  endfor

  return l:adb_devices
endfunction

""
" Shows a dialog that allows user to select a device and returns a list with the
" device ids of the selected devices.
function! adb#selectDevice()

  let l:devices = adb#devices()

  if len(l:devices) == 0
    call android#logw('No devices or emulators present')
    return []
  endif

  if len(l:devices) == 1
    return [ l:devices[0][0] ]
  endif

  let l:choice = -1

  let l:list = ['0. All Devices'] + map(deepcopy(l:devices), '(v:key + 1) . '. ' . s:pretty(v:val)')

  while(l:choice < 0 || l:choice > len(l:devices))
    call inputsave()
    let l:choice = inputlist(l:list)
    call inputrestore()
    echo '\n'
  endwhile

  if l:choice == 0
    return map(l:devices, 'v:val[0]')
  else
    return [ l:devices[l:choice - 1][0] ]
  endif

endfunction

""
" Returns device property as string
function! adb#getProperty(device, property)
  let l:cmd = [
    \ adb#bin(),
    \ '-s',
    \ a:device,
    \ 'shell getprop',
    \ a:property
    \ ]
  return s:chomp(system(join(l:cmd, ' ')))
endfunction

function! adb#getDeviceSdk(device)
  return adb#getProperty(a:device, 'ro.build.version.sdk')
endfunction

function! adb#getDeviceVersion(device)
  return adb#getProperty(a:device, 'ro.build.version.release')
endfunction

function! adb#getDeviceBrand(device)
  return adb#getProperty(a:device, 'ro.product.brand')
endfunction

function! adb#getDeviceModel(device)
  return adb#getProperty(a:device, 'ro.product.model')
endfunction

function! adb#getDeviceManufacturer(device)
  return adb#getProperty(a:device, 'ro.product.manufacturer')
endfunction

function! adb#getDeviceCountry(device)
  return adb#getProperty(a:device, 'persist.sys.country')
endfunction

function! adb#getDeviceLanguage(device)
  return adb#getProperty(a:device, 'persist.sys.language')
endfunction

function! adb#getDeviceTimezone(device)
  return adb#getProperty(a:device, 'persist.sys.timezone')
endfunction

function! adb#getDeviceInfo(device)
  return [
    \ a:device,
    \ adb#getDeviceSdk(a:device),
    \ adb#getDeviceVersion(a:device),
    \ adb#getDeviceModel(a:device),
    \ adb#getDeviceBrand(a:device),
    \ adb#getDeviceManufacturer(a:device)
    \ ]
endfunction

""
" Uninstall android package from device
function! adb#uninstall(device)
  call android#logi('Uninstalling ' . android#packageName() . ' from ' . a:device)
  let l:cmd = adb#bin() . ' -s ' . a:device . ' uninstall ' . android#packageName()
  execute 'silent !' . l:cmd
  redraw!
endfunction

""
" Helper method to sort devices list
function! s:sortFunc(i1, i2)
  return tolower(a:i1[0]) == tolower(a:i2[0]) ? 0 : tolower(a:i1[0]) > tolower(a:i2[0]) ? 1 : -1
endfunction

""
" Helper method to trim spaces
function! s:trim(str)
  return substitute(copy(a:str), '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

""
" Helper method to remove the end \r\n from a string.
function! s:chomp(str)
  let l:noreturn = substitute(copy(a:str), '^\n*\(.\{-}\)\n*$', '\1', '')
  return substitute(l:noreturn, '^\r*\(.\{-}\)\r*$', '\1', '')
endfunction

""
" Helper method to pretty print device info
function! s:pretty(info)
  return '[' . a:info[0] . '] '
      \ . a:info[5] . ' ' . a:info[3] . ' ' . a:info[4]
      \ . ' SDK ' . a:info[2] . ' (API ' . a:info[1] . ')'
endfunction
