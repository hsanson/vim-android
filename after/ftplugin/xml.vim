if android#isAndroidProject()
  if !exists('g:android_sdk_path')
    call android#logw("g:android_sdk_path not set. Disabling android plugin.")
  else
    command! AndroidDebug call android#compile("debug")
    command! AndroidRelease call android#compile("release")
    command! AndroidDebugInstall call android#install("debug")
    command! AndroidReleaseInstall call android#install("release")
  endif
endif
