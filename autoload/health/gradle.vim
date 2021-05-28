
function! health#gradle#check() abort
  if has('nvim')
    call health#gradle#checkNvim()
  else
    call health#gradle#checkVim()
  endif
endfunction

function! health#gradle#checkVim() abort

  echom 'This plugin is developed on NeoVim!, prefer it over vim for a better experience'

  if(!executable(gradle#bin()))
    echom '  Gradle binary not found. Ensure gradle is in your path or set the g:gradle_bin variable.'
  endif

  if(!android#checkAndroidHome())
    echom '  Android home is not set correctly. Ensure g:android_sdk_path variable or ANDROID_HOME environment are set.'
  end

  if(!executable(adb#bin()))
    echom '  ADB binary not found. Ensure g:android_sdk_path variable or the ANDROID_HOME environment are set.'
  endif


endfunction

function! health#gradle#checkNvim() abort
  call health#report_start('vim-android checks')

  call health#report_start('Gradle checks')

  call health#report_ok('Gradle binary: ' . gradle#bin())

  if(empty(gradle#version()))
    call health#report_warn('Gradle version could not be determined')
  else
    call health#report_ok('Gradle version ' . gradle#version())
  endif

  if(gradle#isAsyncEnabled())
    call health#report_ok('Gradle async mode enabled.')
  else
    call health#report_warn('Gradle async mode disabled.', [
         \ 'Consider using neovim with async mode enabled for a better experience.'
         \ ])
  endif

  if(gradle#isDaemonEnabled())
    call health#report_ok('Gradle daemon mode enabled.')
  else
    call health#report_warn('Gradle daemon mode disabled.', [
         \ 'Consider enabling daemon mode for faster builds.'
         \ ])
  endif

  call health#report_start('Android checks')

  if(android#checkAndroidHome())
    call health#report_ok('Android home set to ' . g:android_sdk_path)
  else
    call health#report_error('Android home not set.', [
          \ 'Ensure to set g:android_sdk_path variable correctly,',
          \ 'Or that the ANDROID_HOME environment variable is set.',
          \ ])
  end

  if(executable(android#emulatorbin()))
    call health#report_ok('Android emulator binary found at ' . android#emulatorbin())
  else
    call health#report_error('Android emulator binary not found.', [
        \ 'Ensure you have set g:android_sdk_path variable.',
        \ 'Or have ANDROID_HOME environment variable set.'
        \ ])
  endif

  if(filereadable(android#manifestFile()))
    call health#report_ok('Android manifest found at ' . android#manifestFile())
  else
    call health#report_warn('Android manifest not found.', [
       \ 'Current path maybe not an android project?.'
       \ ])
  endif

  call health#report_start('ADB checks')

  if(executable(adb#bin()))
    call health#report_ok('ADB binary found: ' . adb#bin())
  else
    call health#report_error('ADB binary not found')
  endif

endfunction
