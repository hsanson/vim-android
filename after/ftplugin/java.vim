if gradle#isGradleProject() && !gradle#isGradleDepsCached()
  call gradle#sync()
endif

call gradle#setupGradleCommands()
call android#setupAndroidCommands()
