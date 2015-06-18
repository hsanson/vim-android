" Function that tries to determine the location of the gradle binary. It will
" try first to find the executable inside g:gradle_path and if not found it will
" try using the GRADLE_HOME environment variable. Finally it will search if
" using the vim executable() method.
function! gradle#bin()

  if !exists('g:gradle_path')
    let g:gradle_path = $GRADLE_HOME
  endif

  let g:gradle_bin = g:gradle_path . "/bin/gradle"

  if(!executable(g:gradle_bin))
    if executable("gradle")
      let g:gradle_bin = "gradle"
    else
      echoerr "Gradle tool could not be found"
    endif
  endif

  return g:gradle_bin

endfunction

function! s:gradleCacheDir()
  if ! exists('g:gradle_cache_dir')
    let g:gradle_cache_dir = $HOME . "/.gradle/caches"
  endif
  return g:gradle_cache_dir
endfunction

" Verifies if the android sdk is available and if the gradle build and binary
" are present.
function! gradle#isGradleProject()

  let l:gradle_cfg_exists = filereadable(gradle#findGradleFile())
  let l:gradle_bin_exists = executable(gradle#bin())

  if( ! l:gradle_cfg_exists )
    call android#loge("Could not find any build.gradle or build.xml file... aborting")
    return 0
  endif

  if( ! l:gradle_bin_exists )
    call android#loge("Could not find gradle binay")
    return 0
  endif

  return 1
endfunction

" Function that compiles and installs the android app into a device.
" a:device is the device or emulator to which we want to install
" a:mode can be any of the compile modes supported by the build system (e.g.
" debug or release).
function! gradle#install(device, mode)
  let l:cmd = "ANDROID_SERIAL=" . a:device . " " . gradle#bin() . ' -f ' . g:gradle_file . ' install' . android#capitalize(a:mode)
  call android#logi("Installing " . a:mode . " to " . a:device . " (wait...)")
  let l:output = system(l:cmd)
  redraw!
  let l:failure = matchstr(l:output, "Failure")
  if empty(l:failure)
    call android#logi("Installation finished on " . a:device)
    return 0
  else
    let l:errormsg = matchstr(l:output, '\cFailure \[\zs.\{-}\ze\]')
    call android#loge("Installation failed on " . a:device . " with error " . l:errormsg)
    return 1
  endif
endfunction

function! gradle#findGradleFile()
  let l:file = findfile("build.gradle", expand("%:p:h") . "/**;$HOME")
  if match(l:file, "/") != 0
    let l:file = getcwd() . "/" . l:file
  endif
  return l:file
endfunction

function! gradle#findRoot()
  return fnamemodify(gradle#findGradleFile(), ":p:h")
endfunction

function! gradle#getTargetVersion() 
  let l:androidTarget = "UNDEFINED"
  let l:gradleFile = gradle#findGradleFile()
  if filereadable(l:gradleFile)
    for line in readfile(l:gradleFile)
      if line =~ 'compileSdkVersion'
        let l:androidTarget = split(substitute(line, "['\"]", '', "g"), ' ')[-1]
        if stridx(l:androidTarget, ':') > 0
          let l:androidTarget = split(l:androidTarget, ':')[1]
        endif
      endif
    endfor
  endif
  return l:androidTarget
endfunction

function! gradle#getTargetJarPath()
  let l:targetJar = g:android_sdk_path . '/platforms/android-' . gradle#getTargetVersion() . '/android.jar'
  return l:targetJar
endfunction

function! gradle#getTargetSrcPath()
  let l:targetSrc = g:android_sdk_path . '/sources/andoird-' . gradle#getTargetVersion() . '/'
  return targetSrc
endfunction

function! gradle#setCompiler()
  if gradle#isGradleProject()
    silent! execute("compiler gradle")
  endif
endfunction

function! gradle#isCompilerSet()
  if(exists("b:current_compiler") && b:current_compiler == "gradle")
    return 1
  else
    return 0
  endif
endfunction

function! gradle#run(...)

  call gradle#setCompiler()

  if(!gradle#isCompilerSet())
    call android#logw("Android compiler not set")
    return 1
  endif

  let shellpipe = &shellpipe

  let &shellpipe = '2>'

  call android#logi("Compiling " . join(a:000, " "))

  "if exists('g:loaded_dispatch')
  ""  silent! exe 'Make'
  "else
    execute("silent! make " . join(a:000, " "))
    redraw!
  "endif

  " Restore previous values
  let &shellpipe = shellpipe
  return s:getErrorCount()
endfunction

" This method returns the number of valid errors in the quickfix window. This
" allows us to check if there are errors after compilation.
function! s:getErrorCount()
  let l:list = deepcopy(getqflist())
  return len(filter(l:list, "v:val['valid'] > 0"))
endfunction

" Find jar file locations for all libraries declared in the build.gradle file
" via compile directive.
function! gradle#getJarList()

  let l:jars = []
  let l:dependencies = gradle#getDependencies(android#getProjectName())

  for dep in l:dependencies
    call s:addAar(dep[0], dep[1], dep[2], l:jars)
    call s:addJar(dep[1], dep[2], l:jars)
  endfor

  return l:jars
endfunction

function! gradle#getDependenciesCache(project)
  if !exists('s:dependenciesCache')
    let s:dependenciesCache = {}
  endif

  if !has_key(s:dependenciesCache, a:project)
    let s:dependenciesCache[a:project] = []
  endif

  return s:dependenciesCache[a:project]
endfunction

function! s:addDependenciesCache(project, deps)
  if !exists('s:dependenciesCache')
    let s:dependenciesCache = {}
  endif
  let s:dependenciesCache[a:project] = a:deps
endfunction

" Executes *gradle dependencies" and parses the list of dependencies returned.
function! gradle#getDependenciesFromGradle()
  let l:dependencies = []
  let l:gradle_output = split(system(gradle#bin() . ' dependencies'), '\n')

  for line in l:gradle_output
    let sanitized_line = substitute(line, "\'", '"', "g")
    " Match strings of the form: compile 'com.squareup.okhttp:okhttp-urlconnection:2.0.0' with
    " the library part and version separated into mlist[2] and mlist[3]
    let mlist = matchlist(sanitized_line,  '^.*---\s\(\S\+\):\(\S\+\):\(\S\+\)\s*.*$')
    if empty(mlist) == 0 && len(mlist[1]) > 0 && len(mlist[2]) > 0 && len(mlist[3]) > 0
      call add(l:dependencies, [mlist[1], mlist[2], mlist[3]])
    endif
  endfor
  return l:dependencies
endfunction

" Reads the build.gradle file and extracts all declared dependencies via the
" compile keyword.
function! gradle#getDependenciesFromBuildFile()

  let l:dependencies = []

  let l:gradleFile = gradle#findGradleFile()

  if ! filereadable(l:gradleFile)
    return l:dependencies
  endif

  for line in readfile(l:gradleFile)
    let sanitized_line = substitute(line, "\'", '"', "g")
    " Match strings of the form: compile 'com.squareup.okhttp:okhttp-urlconnection:2.0.0' with
    " the library part and version separated into mlist[2] and mlist[3]
    let mlist = matchlist(sanitized_line,  '^\s*compile\s\+"\(.\+\):\(.\+\):\(.\+\)"')
    if empty(mlist) == 0 && len(mlist[1]) > 0 && len(mlist[2]) > 0 && len(mlist[3]) > 0
      call add(l:dependencies, [mlist[1], mlist[2], mlist[3]])
    endif
  endfor
  return l:dependencies
endfunction

" Return a list of dependencies for project
function! gradle#getDependencies(project)
  let l:dependencies = gradle#getDependenciesCache(a:project)

  if !empty(l:dependencies)
    return l:dependencies
  endif

  echo "Loading gradle dependencies, may take several seconds, please wait..."

  let l:dependencies = gradle#getDependenciesFromGradle()

  if empty(l:dependencies)
    let l:dependencies = gradle#getDependenciesFromBuildFile()
  endif

  if !empty(l:dependencies)
    call s:addDependenciesCache(a:project, l:dependencies)
  endif

  echon " finished."

  silent! redraw

  return l:dependencies
endfunction

function! s:getCache()
  if !exists('s:cache')
    let s:cache = {}
  endif
  return s:cache
endfunction

function! s:findInCache(name)
  let l:cache = s:getCache()
  return has_key(s:getCache(), a:name)
endfunction

function! s:getFromCache(name)
  let l:cache = s:getCache()
  return l:cache[a:name]
endfunction

function! s:addToCache(name, path)
  let l:cache = s:getCache()
  let l:cache[a:name] = a:path
endfunction

function! s:findInFileSystem(name)
  return findfile(a:name, s:gradleCacheDir() . "/**," . g:android_sdk_path . "/extras/**")
endfunction

" Look for jar files in the gradle caches directories and android sdk extras and
" add them to the argument list.
function! s:addJar(name, version, list)
  let l:name = a:name . "-" . a:version
  let l:jarName = l:name . ".jar"
  let l:jar = s:findInCache(l:jarName)

  if s:findInCache(l:name)
    let l:jar = s:getFromCache(l:name)
  else
    let l:jar = s:findInFileSystem(l:jarName)
    call s:addToCache(l:name, l:jar)
  endif

  if len(l:jar) > 0
    call add(a:list, l:jar)
    return 1
  else
    return 0
  endif
endfunction

" Look for jar files for libraries inside the exploded-aar folder within the
" gradle project.
function! s:addAar(package, name, version, list)

  let l:name = a:name . "-" . a:version
  let l:jar = ''

  if s:findInCache(l:name)
    let l:jar = s:getFromCache(l:name)
  else
    let l:path = gradle#findRoot() . "/build/intermediates/exploded-aar/" . a:package . "/" . a:name . "/" . a:version . "/classes.jar"
    if filereadable(l:path)
      let l:jar = l:path
      call s:addToCache(l:name, l:jar)
    endif
  endif

  if len(l:jar) > 0
    call add(a:list, l:jar)
    return 1
  else
    return 0
  endif

endfunction
