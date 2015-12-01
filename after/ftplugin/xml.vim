if gradle#isGradleProject()

  call gradle#setClassPath()
  call gradle#setupGradleCommands()

  if android#isAndroidProject()
    call android#setAndroidSdkTags()
    call android#setClassPath()
    call android#setupAndroidCommands()
  endif

endif
