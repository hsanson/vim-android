if gradle#isGradleProject()
  call gradle#sync()
endif

silent! call javacomplete#SetClassPath($CLASSPATH)
silent! call javacomplete#SetSourcePath($SRCPATH)

if exists(":JCstart")
  let $CLASSPATH = g:JavaComplete_LibsPath
  let $SRCPATH = g:JavaComplete_SourcesPath
endif

let g:syntastic_java_javac_classpath = $CLASSPATH . ":" . $SRCPATH

call gradle#setupGradleCommands()
call android#setupAndroidCommands()
