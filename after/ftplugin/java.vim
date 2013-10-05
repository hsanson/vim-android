if android#isAndroidProject()
  call android#setAndroidSdkTags()
  call android#setClassPath()
  call android#setupAndroidCommands()
endif
