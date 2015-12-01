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

let g:JavaComplete_LibsPath = $CLASSPATH
let g:JavaComplete_SourcesPath = $SRCPATH

let g:syntastic_java_javac_classpath = $CLASSPATH

silent! call javacomplete#StartServer()

