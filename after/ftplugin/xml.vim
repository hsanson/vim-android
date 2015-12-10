if gradle#isGradleProject()

  call gradle#setClassPath()
  call gradle#setupGradleCommands()

  if android#isAndroidProject()
    call android#setAndroidSdkTags()
    call android#setClassPath()
    call android#setupAndroidCommands()

    if expand('%:t') == 'AndroidManifest.xml'
      XMLns manifest
    else
      XMLns android
    endif
  endif

endif
