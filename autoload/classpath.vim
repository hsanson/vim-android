""
" Adds the current android project classes to the classpath
function! s:addProjectClassPath(paths, jars)
  " Add our project classes path
  let l:local = fnamemodify('./bin/classes', ':p')
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

""
" Parse project.properties file if available and add all library dependencies to the
" classpath
function! s:addPropertiesClassPath(dir, paths, jars)

  let l:properties = a:dir . '/project.properties'

  if filereadable(l:properties)
    for line in readfile(l:properties)
      if line =~ 'android.library.reference'
        let l:path = split(line, '=')[1]
        let l:referenceJar = substitute(fnamemodify(l:path . "/bin/classes.jar", ':p'), '/*$', '', '')
        if filereadable(l:referenceJar)
          if index(s:oldjars, l:referenceJar) == -1 && index(a:jars, l:referenceJar) == -1
            call add(a:jars, l:referenceJar)
          endif
        endif

        " Load jars in libs to classpath
        call s:addLibJarClassPath(l:path, a:jars)

        " Recursively call this method on all reference libraries
        call s:addPropertiesClassPath(l:path, a:paths, a:jars)
      endif
    endfor

    " A property files may indicate an ant project that contains the source code
    " in a folder called src in the project root.
    if isdirectory("./src")
      call add(a:paths, "./src")
    endif
  end
endfunction

""
" Parse build.gradle file if available and add all library dependencies to the
" list of paths.
"
" TODO: Currently we only add the jars and src dirs of library projects. We need
" to find a way to resolve copile dependencies retrieved via maven repos to the
" list of jars in the CLASSPATH
function! s:addGradleClassPath(dir, paths, jars)

  let l:gradle = a:dir . '/build.gradle'

  if filereadable(l:gradle)
    for line in readfile(l:gradle)
      let sanitized_line = substitute(line, "\'", '"', "g")
      let mlist = matchlist(sanitized_line, 'compile\s\+project\s*("\([^"]*\)")')
      if empty(mlist) == 0 && len(mlist[1]) > 0
        let l:path = "." . substitute(mlist[1], ":", "/", "g")
        let l:referenceJar = fnamemodify(l:path . "/build/bundles/debug/classes.jar", ':p')
        if filereadable(l:referenceJar)
          if index(s:oldjars, l:referenceJar) == -1 && index(a:jars, l:referenceJar) == -1
            call add(a:jars, l:referenceJar)
          endif
        endif

        " Load jars in libs to classpath
        call s:addLibJarClassPath(l:path, a:jars)

        " Recursively call this method on all reference libraries
        call s:addGradleClassPath(l:path, a:paths, a:jars)
      endif

      " Add all srcDirs definitions
      let mlist = matchlist(sanitized_line, 'srcDirs\s*=\s*\["\([^"]*\)"\]')
      if empty(mlist) == 0 && len(mlist[1]) > 0
        let l:path = fnamemodify(a:dir . '/' . mlist[1], ':p')
        if isdirectory(l:path) && index(a:paths, l:path) == -1
          call add(a:paths, l:path)
        endif
      endif
    endfor

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
  end
endfunction

" Add the android.jar and source path for the SDK version defined in the AndroidManifest.xml
function! s:addManifestSdkJar(paths, jars)
  for line in readfile(android#findManifest())
    if line =~ 'android:targetSdkVersion='
      let l:androidTarget = matchstr(line, '\candroid:targetSdkVersion=\([''"]\)\zs.\{-}\ze\1')
      let l:androidTargetPlatform = 'android-' . l:androidTarget
      let l:targetAndroidJar = g:android_sdk_path . '/platforms/' . l:androidTargetPlatform . '/android.jar'
      let l:targetAndroidSrc = g:android_sdk_path . '/sources/' . l:androidTargetPlatform . '/'
      if index(s:oldjars, l:targetAndroidJar) == -1 && index(a:jars, l:targetAndroidJar) == -1
        call add(a:jars, l:targetAndroidJar)
      endif
      if isdirectory(l:targetAndroidSrc) && index(a:paths, l:targetAndroidSrc) == -1
        call add(a:paths, l:targetAndroidSrc)
      endif
      break
    endif
  endfor
endfunction

" Add the android.jar for the SDK version defined in the build.gradle and the
" android sources path.
function! s:addGradleSdkJar(paths, jars)
  if filereadable('build.gradle')
    for line in readfile('build.gradle')
      if line =~ 'compileSdkVersion'
        let l:androidTarget = split(line, ' ')[-1]
        if stridx(l:androidTarget, ':') > 0
            let l:androidTarget = split(l:androidTarget, ':')[1]
        endif
        if stridx(l:androidTarget, '"') > 0
            let l:androidTarget = split(l:androidTarget, '"')[0]
        endif
        let l:androidTargetPlatform = 'android-' . l:androidTarget
        let l:targetAndroidJar = g:android_sdk_path . '/platforms/' . l:androidTargetPlatform . '/android.jar'
        let l:targetAndroidSrc = g:android_sdk_path . '/sources/' . l:androidTargetPlatform . '/'
        if index(s:oldjars, l:targetAndroidJar) == -1 && index(a:jars, l:targetAndroidJar) == -1
          call add(a:jars, l:targetAndroidJar)
        endif
        if isdirectory(l:targetAndroidSrc) && index(a:paths, l:targetAndroidSrc) == -1
          call add(a:paths, l:targetAndroidSrc)
        endif
        break
      endif
    endfor
  end
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

  call s:addProjectClassPath(s:paths, s:jars)
  if android#isGradleProject()
    call s:addGradleSdkJar(s:paths, s:jars)
    call s:addGradleClassPath(getcwd(), s:paths, s:jars)
  else
    call s:addManifestSdkJar(s:paths, s:jars)
    call s:addPropertiesClassPath(getcwd(), s:paths, s:jars)
  endif
  call s:addLibJarClassPath(getcwd(), s:jars)

  call extend(s:jars, s:oldjars)

  let $CLASSPATH = join(copy(s:jars), ':')
  let $SRCPATH = join(copy(s:paths), ':')
  exec "setlocal path=" . join(copy(s:paths), ',')

  silent! call javacomplete#SetClassPath($CLASSPATH)
  silent! call javacomplete#SetSourcePath($SRCPATH)


endfunction
