function! health#gradle#check() abort
  call health#report_start('vim-android checks')

  if has('nvim')
    call health#report_ok('has("nvim") was successful')
  else
    call health#report_warning('has("nvim") was not successful',
          \ 'vim-android works best with neovim!')
  endif

  call health#report_start('Gradle checks')

  if(executable(gradle#bin()))
    call health#report_ok("Gradle binary found at " . gradle#bin())
  else
    call health#report_error("Gradle binary not found", [
          \ 'Ensure gradle is in your path or that the project has gradlew script.',
          \ 'Set the g:gradle_bin variable is still having issues.'
          \])
  endif

  if(gradle#isAsyncEnabled())
    call health#report_ok("Gradle async mode enabled.")
  else
    call health#report_warn("Gradle async mode disabled.", [
         \ 'Consider using neovim with async mode enabled for a better experience.'
         \ ])
  endif

  if(gradle#isDaemonEnabled())
    call health#report_ok("Gradle daemon mode enabled.")
  else
    call health#report_warn("Gradle daemon mode disabled.", [
         \ 'Consider enabling daemon mode for faster builds.'
         \ ])
  endif

  call health#report_info("Gradle version " . gradle#version())

  call health#report_start('Android checks')

  if(executable(android#bin()))
    call health#report_ok("Android binary found at " . android#bin())
  else
    call health#report_error("Android binary not found.", [
        \ 'Ensure you have set g:android_sdk_path variable.',
        \ 'Or have ANDROID_HOME environment variable set.'
        \ ])
  endif

  if(android#checkAndroidHome())
    call health#report_ok("Android home set to " . g:android_sdk_path)
  else
    call health#report_error("Adnroid home not set.", [
          \ 'Ensure to set g:android_sdk_path variable correctly.'
          \ ])
  end

  if(executable(android#emulatorbin()))
    call health#report_ok("Android emulator binary found at " . android#emulatorbin())
  else
    call health#report_error("Android emulator binary not found.", [
        \ 'Ensure you have set g:android_sdk_path variable.',
        \ 'Or have ANDROID_HOME environment variable set.'
        \ ])
  endif

  if(filereadable(android#findManifestFile()))
    call health#report_ok("Android manifest found at " . android#findManifestFile())
  else
    call health#report_warn("Android manifest not found.", [
       \ 'Current path maybe not an android project?.'
       \ ])
  endif

  let indentation = '        '

  call health#report_info("Configured glyps:\n" .
        \ indentation . "android glyph: " . android#glyph() . "\n" .
        \ indentation . "gradle glyph:  " . gradle#glyph() . "\n" .
        \ indentation . "error glyph:   " . gradle#glyphError() . "\n" .
        \ indentation . "warning glyph: " . gradle#glyphWarning() . "\n" .
        \ indentation . "building glyph: " . gradle#glyphBuilding() . "\n"
        \ )

  call health#report_start('ADB checks')

  if(executable(adb#bin()))
    call health#report_ok("ADB binary found: " . adb#bin())
  else
    call health#report_error("ADB binary not found")
  endif

  "health#report_info
  "health#report_error
  "health#report_warn
endfunction
