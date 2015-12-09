if gradle#isGradleProject()
  if android#isAndroidProject()
    autocmd BufEnter *.xml XMLns android
    autocmd BufEnter AndroidManifest.xml XMLns manifest
  endif
endif
