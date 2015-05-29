""
" Adds the current android project classes to the classpath
function! s:addProjectClassPath(paths, jars)
  " Add our project classes path
  let l:local = fnamemodify('build/intermediates/bundles/debug/classes.jar', ':p')
  if index(s:oldjars, l:local) == -1 && index(a:jars, l:local) == -1
    call add(a:jars, l:local)
  endif
endfunction

""
" Load all jar files inside libs folder to classpath
function! s:addLibJarClassPath(dir, jars)
  let wildignore = &wildignore
  let &wildignore = ''
  for jarfile in split(globpath(a:dir . "/libs/", "*.jar"), '\n')
    if index(s:oldjars, jarfile) == -1 && index(a:jars, jarfile) == -1
      call add(a:jars, jarfile)
    endif
  endfor
  let &wildignore = wildignore
endfunction

function! s:addGradlePaths(dir, paths)
  " By default gradle projects have well defined source structure. Make sure
  " we add it the the path
  let l:javapath = fnamemodify(a:dir . "/src/main/java", ':p')
  let l:respath = fnamemodify(a:dir . "/src/main/res", ':p')
  if isdirectory(l:javapath) && index(a:paths, l:javapath) == -1
    call add(a:paths, l:javapath)
  endif
  if isdirectory(l:respath) && index(a:paths, l:respath) == -1
    call add(a:paths, l:respath)
  endif
endfunction

" Add the android.jar for the SDK version defined in the build.gradle and the
" android sources path.
function! s:addGradleSdkJar(paths, jars)
  let l:targetAndroidJar = gradle#getTargetJarPath()
  let l:targetAndroidSrc = gradle#getTargetSrcPath()
  if index(s:oldjars, l:targetAndroidJar) == -1 && index(a:jars, l:targetAndroidJar) == -1
    call add(a:jars, l:targetAndroidJar)
  endif
  if isdirectory(l:targetAndroidSrc) && index(a:paths, l:targetAndroidSrc) == -1
    call add(a:paths, l:targetAndroidSrc)
  endif
endfunction

function! s:addGradleLibJars(jars)
  let l:jars = gradle#getJarList()
  for jar in l:jars
    if index(s:oldjars, jar) == -1 && index(a:jars, jar) == -1
      call add(a:jars, jar)
    endif
  endfor
endfunction

""
" Update the CLASSPATH environment variable to include all classes related to
" the current Android project.
function! classpath#setClassPath()

  if ! android#checkAndroidHome()
    return
  endif

  let s:paths = []  " List of source directories
  let s:jars  = []  " List of jar files to include in CLASSPATH

  " Obtain a list of current paths in the $CLASSPATH
  let s:oldjars = split($CLASSPATH, ':')
  let l:root = gradle#findRoot()

  call s:addProjectClassPath(s:paths, s:jars)
  call s:addGradleSdkJar(s:paths, s:jars)
  call s:addGradleLibJars(s:jars)
  call s:addGradlePaths(l:root, s:paths)
  call s:addLibJarClassPath(l:root, s:jars)

  call extend(s:jars, s:oldjars)

  let $CLASSPATH = join(copy(s:jars), ':')
  let $SRCPATH = join(copy(s:paths), ':')
  exec "setlocal path=" . join(copy(s:paths), ',')

  silent! call javacomplete#SetClassPath($CLASSPATH)
  silent! call javacomplete#SetSourcePath($SRCPATH)

  let g:JavaComplete_LibsPath = $CLASSPATH
  let g:JavaComplete_SourcesPath = $SRCPATH

  silent! call javacomplete#StartServer()

endfunction
