if gradle#isGradleProject()

  call gradle#sync()

  if android#isAndroidProject()
    if expand('%:t') == 'AndroidManifest.xml'
      XMLns manifest
    else
      XMLns android
    endif
  endif

endif
