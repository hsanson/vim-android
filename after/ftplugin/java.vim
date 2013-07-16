if android#isAndroidProject()
  call android#setAndroidSdkTags()
  call android#setAndroidJarInClassPath()
  call android#setupAndroidCommands()
endif
