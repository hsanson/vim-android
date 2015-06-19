
function! s:getProjectJar()
  let l:local = fnamemodify('build/intermediates/bundles/debug/classes.jar', ':p')
  if filereadable(l:local)
    return l:local
  endif
endfunction

""
" Find all jar files located inside the libs folder
function! s:getLibJars()
  return globpath(gradle#findRoot() . "/libs", "**/*.jar", 1,1)
endfunction

function! s:getGradleSrcPaths()
  " By default gradle projects have well defined source structure. Make sure
  " we add it the the path
  let l:srcs = []
  let l:javapath = fnamemodify(gradle#findRoot() . "/src/main/java", ':p')
  let l:respath = fnamemodify(gradle#findRoot() . "/src/main/res", ':p')

  if isdirectory(l:javapath)
    call add(l:srcs, l:javapath)
  endif

  if isdirectory(l:respath)
    call add(l:srcs, l:respath)
  endif

  return l:srcs
endfunction

""
" Update the CLASSPATH environment variable to include all classes related to
" the current Android project.
function! classpath#setClassPath()

  if ! android#checkAndroidHome()
    return
  endif

  let l:jarList = []

  let l:oldJars = split($CLASSPATH, ':')
  call extend(l:jarList, l:oldJars)

  let l:projectJar = s:getProjectJar()
  if len(l:projectJar) > 0
    call add(l:jarList, l:projectJar)
  endif

  let l:targetJar = gradle#getTargetJarPath()
  if len(l:projectJar) > 0
    call add(l:jarList, l:targetJar)
  endif

  let l:depJars = gradle#getJarList()
  if !empty(l:depJars)
    call extend(l:jarList, l:depJars)
  endif

  let l:libJars = s:getLibJars()
  if !empty(l:libJars)
    call extend(l:jarList, l:libJars)
  endif

  let l:srcList = []

  let l:targetSrc = gradle#getTargetSrcPath()
  if len(l:targetSrc) > 0
    call add(l:srcList, l:targetSrc)
  endif

  let l:gradleSrcPaths = s:getGradleSrcPaths()
  if !empty(l:gradleSrcPaths)
    call extend(l:srcList, l:gradleSrcPaths)
  endif

  let l:jarList = uniq(sort(l:jarList))
  let l:srcList = uniq(sort(l:srcList))

  let $CLASSPATH = join(l:jarList, ':')
  let $SRCPATH = join(l:srcList, ':')
  exec "setlocal path=" . join(l:srcList, ',')

  silent! call javacomplete#SetClassPath($CLASSPATH)
  silent! call javacomplete#SetSourcePath($SRCPATH)

  let g:JavaComplete_LibsPath = $CLASSPATH
  let g:JavaComplete_SourcesPath = $SRCPATH

  let g:syntastic_java_javac_classpath = $CLASSPATH

  silent! call javacomplete#StartServer()

endfunction
