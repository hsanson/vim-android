if gradle#isGradleProject()
  call gradle#createGradleInitFile()
  call gradle#setClassPath()
  call gradle#setupGradleCommands()
endif

if android#isAndroidProject()
  call android#setAndroidSdkTags()
  call android#setClassPath()
  call android#setupAndroidCommands()
endif
