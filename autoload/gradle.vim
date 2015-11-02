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

" Determines the path where the gradle cached files are located. This includes
" dependencties jar and aar files. If the g:gradle_cache_dir variable is defined
" it uses it as path location, otherwise it uses $HOME/.gradle/caches.
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
    call android#loge("Could not find gradle binary. You may want to set g:gradle_bin variable")
    return 0
  endif

  return 1
endfunction

" Function that compiles and installs the android app into a device.
" a:device is the device or emulator id as displayed by *adb devices* command.
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

" Tries to determine the location of the build.gradle file starting from the
" current buffer location.
function! gradle#findGradleFile()
  let l:file = findfile("build.gradle", expand("%:p:h") . "/**;$HOME")
  if match(l:file, "/") != 0
    let l:file = getcwd() . "/" . l:file
  endif
  return l:file
endfunction

" Tries to find the root of the android project. It uses the build.gradle file
" location as root. This allows vim-android to work with multi-project
" environments.
function! gradle#findRoot()
  return fnamemodify(gradle#findGradleFile(), ":p:h")
endfunction

" Determines the target SDK version of the project by reading the build.gradle
" file and looking for the compileSdkVersion variable.
function! gradle#getTargetVersion() 
  let l:androidTarget = "UNDEFINED"
  let l:gradleFile = gradle#findGradleFile()
  if filereadable(l:gradleFile)
    for line in readfile(l:gradleFile)
      let l:matches = matchlist(line, 'compileSdkVersion\s\+.\+\(\d\d\).$')
      if !empty(l:matches)
        let l:androidTarget = l:matches[1]
      endif
    endfor
  endif
  return l:androidTarget
endfunction

" Find the android sdk jar file for the target sdk version.
function! gradle#getTargetJarPath()
  let l:targetJar = g:android_sdk_path . '/platforms/android-' . gradle#getTargetVersion() . '/android.jar'
  if filereadable(l:targetJar)
    return l:targetJar
  endif
endfunction

" Find the adroid sdk srouce files for the target sdk version.
function! gradle#getTargetSrcPath()
  let l:targetSrc = g:android_sdk_path . '/sources/android-' . gradle#getTargetVersion() . '/'
  if isdirectory(l:targetSrc)
    return targetSrc
  endif
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
  return [s:getErrorCount(), s:getWarningCount()]
endfunction

" This method returns the number of valid errors in the quickfix window. This
" allows us to check if there are errors after compilation.
function! s:getErrorCount()
  let l:list = deepcopy(getqflist())
  return len(filter(l:list, "v:val['valid'] > 0 && tolower(v:val['type']) != 'w'"))
endfunction

" This method returns the number of valid warnings in the quickfix window. This
" allows us to check if there are errors after compilation.
function! s:getWarningCount()
  let l:list = deepcopy(getqflist())
  return len(filter(l:list, "v:val['valid'] > 0 && tolower(v:val['type']) == 'w'"))
endfunction

" Find jar file locations for all libraries declared in the build.gradle file
" via compile directive. The first time this method runs it can take several
" seconds because it executes the command *gradle depedencies* to find the
" dependencies.
function! gradle#getJarList()

  let l:jars = []
  let l:dependencies = gradle#getDependencies(android#packageName())

  for dep in l:dependencies
    call s:addJar(dep[1], dep[2], l:jars)
  endfor

  return l:jars
endfunction

function! gradle#getDependenciesCache(package)
  if !exists('g:dependenciesCache')
    let g:dependenciesCache = {}
  endif

  if !has_key(g:dependenciesCache, a:package)
    let g:dependenciesCache[a:package] = []
  endif

  return g:dependenciesCache[a:package]
endfunction

function! s:addDependenciesCache(package, deps)
  if !exists('g:dependenciesCache')
    let g:dependenciesCache = {}
  endif
  let g:dependenciesCache[a:package] = a:deps
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

  echo "Loading gradle dependencies for " . a:project . ", may take several seconds, please wait..."

  let l:dependencies = gradle#getDependenciesFromGradle()

  if empty(l:dependencies)
    let l:dependencies = gradle#getDependenciesFromBuildFile()
  endif

  if !empty(l:dependencies)
    call s:addDependenciesCache(a:project, l:dependencies)
  endif

  echon " finished."

  redraw!

  return l:dependencies
endfunction

""
" Update the CLASSPATH environment variable to include all classes related to
" the current Android project.
function! gradle#setClassPath()

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

  let l:jarList = s:uniq(sort(l:jarList))
  let l:srcList = s:uniq(sort(l:srcList))

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
function! s:getCache()
  return s:preloadCache()
endfunction

function! s:getFromCache(name)
  let l:cache = s:getCache()
  if has_key(l:cache, a:name)
    return l:cache[a:name]
  end
endfunction

" Force preloading of jar list cache
function! gradle#loadCache()
  return s:loadCache()
endfunction

" Preload jar list cache only if not loaded already.
function! s:preloadCache()

  if exists("s:cache")
    return s:cache
  endif

  return s:loadCache()

endfunction

" Load list of jar files located in the android sdk
" extras, exploded aars and the gradle cache.
function! s:loadCache()

  echo "Preloading jar list cache"

  let s:cache = {}

  let l:jars = split(globpath(g:android_sdk_path . "/extras," . s:gradleCacheDir(), "**/*.jar", 1), "\n")
  for jar in l:jars
    let l:basename = fnamemodify(jar, ":t:r")
    let s:cache[l:basename] = jar
  endfor

  let l:aars = split(globpath(gradle#findRoot() . "/build/intermediates/exploded-aar", "**/classes.jar", 1), "\n")
  for aar in l:aars
    let mlist = split(aar,  '/')
    if mlist[-1] == "classes.jar"
      let l:name = mlist[-3] . "-" . mlist[-2]
      let s:cache[l:name] = aar
    endif
  endfor

  return s:cache

endfunction

" Look for jar files in the gradle caches directories and android sdk extras and
" add them to the argument list.
function! s:addJar(name, version, list)
  let l:name = a:name . "-" . a:version
  let l:jarName = l:name . ".jar"

  let l:jar = s:getFromCache(l:name)

  if len(l:jar) > 0
    call add(a:list, l:jar)
  endif
endfunction

function! s:getProjectJar()
  let l:local = fnamemodify('build/intermediates/bundles/debug/classes.jar', ':p')
  if filereadable(l:local)
    return l:local
  endif
endfunction

""
" Find all jar files located inside the libs folder
function! s:getLibJars()
  return split(globpath(gradle#findRoot() . "/libs", "**/*.jar", 1), "\n")
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

" Compatibility function.
" This s:uniq() function will use the built in uniq() function for vim >
" 7.4.218 and a custom implementation of older versions.
"
" NOTE: This method only works on sorted lists. If they are not sorted this will
" not result in a uniq list of elements!!
"
" Stolen from: https://github.com/LaTeX-Box-Team/LaTeX-Box/pull/223
function! s:uniq(list)

  if exists('*uniq')
    return uniq(a:list)
  endif

  if len(a:list) <= 1
    return a:list
  endif

  let last_element = get(a:list,0)
  let uniq_list = [last_element]

  for i in range(1, len(a:list)-1)
    let next_element = get(a:list, i)
    if last_element == next_element
      continue
    endif
    let last_element = next_element
    call add(uniq_list, next_element)
  endfor

  return uniq_list

endfunction
