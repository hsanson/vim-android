if android#isAndroidProject()
  call android#setCompiler()
  call android#setAndroidSdkTags()
  call android#setClassPath()
  call android#setupAndroidCommands()
endif
