if gradle#syncOnLoad() && gradle#isGradleProject() && !gradle#isGradleDepsCached()
  call gradle#sync()
endif

call gradle#setupGradleCommands()
call android#setupAndroidCommands()
call ale_linters#java#android#Define('kotlin')
