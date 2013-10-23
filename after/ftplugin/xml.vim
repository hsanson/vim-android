if android#isAndroidProject()
  call android#findProjectType()
  call android#setAndroidSdkTags()
  call android#setClassPath()
  call android#setupAndroidCommands()
endif
