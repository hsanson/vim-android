if gradle#isGradleProject()

  call gradle#setClassPath()
  call gradle#setupGradleCommands()

  if android#isAndroidProject()
    call android#setAndroidSdkTags()
    call android#setClassPath()
    call android#setupAndroidCommands()
  endif

endif

silent! call javacomplete#SetClassPath($CLASSPATH)
silent! call javacomplete#SetSourcePath($SRCPATH)

if exists(":JCstart")
  let $CLASSPATH = g:JavaComplete_LibsPath
  let $SRCPATH = g:JavaComplete_SourcesPath
endif

let g:syntastic_java_javac_classpath = $CLASSPATH . ":" . $SRCPATH
