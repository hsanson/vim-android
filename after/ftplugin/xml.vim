if gradle#syncOnLoad() && gradle#isGradleProject()

  if !gradle#isGradleDepsCached()
    call gradle#sync()
  endif

  if android#isAndroidProject()
    if expand('%:t') == 'AndroidManifest.xml'
      XMLns manifest
    else
      XMLns android
    endif
  endif

endif

call gradle#setupGradleCommands()
call android#setupAndroidCommands()
call ale_linters#android#Define('xml')
