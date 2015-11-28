function! gradle#logi(msg)
  redraw
  echomsg "gradle: " . a:msg
endfunction

function! gradle#logw(msg)
  echohl warningmsg
  echo "gradle: " . a:msg
  echohl normal
endfunction

function! gradle#loge(msg)
  echohl errormsg
  echo "gradle: " . a:msg
  echohl normal
endfunction

let s:pluginDir = expand("<sfile>:p:h:h")

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

" Create gradle init file with custom tasks used by this plugin.
function! gradle#createGradleInitFile()
  let srcPath = s:pluginDir . "/gradle"
  let dstPath = $HOME . "/.gradle/init.d"
  call mkdir(dstPath, "p")
  call system("/bin/cp " . srcPath . "/init.gradle " . dstPath . "/vim-gradle.gradle")
endfunction

" Verifies if the android sdk is available and if the gradle build and binary
" are present.
function! gradle#isGradleProject()

  let l:gradle_cfg_exists = filereadable(gradle#findGradleFile())
  let l:gradle_bin_exists = executable(gradle#bin())

  if( ! l:gradle_cfg_exists )
    call gradle#loge("Could not find any build.gradle or build.xml file... aborting")
    return 0
  endif

  if( ! l:gradle_bin_exists )
    call gradle#loge("Could not find gradle binary. You may want to set g:gradle_bin variable")
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
  call gradle#logi("Installing " . a:mode . " to " . a:device . " (wait...)")
  let l:output = system(l:cmd)
  redraw!
  let l:failure = matchstr(l:output, "Failure")
  if empty(l:failure)
    call gradle#logi("Installation finished on " . a:device)
    return 0
  else
    let l:errormsg = matchstr(l:output, '\cFailure \[\zs.\{-}\ze\]')
    call gradle#loge("Installation failed on " . a:device . " with error " . l:errormsg)
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

function! gradle#compile(...)

  let l:result = call("gradle#run", a:000)

  if(l:result[0] == 0 && l:result[1] == 0)
    call gradle#logi("Building finished successfully")
  elseif(l:result[0] > 0)
    call gradle#loge("Building finished with " . l:result[0] . " errors and " . l:result[1] . " warnings.")
  else
    call gradle#logi("Building finished with " . l:result[1] . " warnings.")
  endif

endfunction

function! gradle#run(...)

  call gradle#setCompiler()

  let shellpipe = &shellpipe

  let &shellpipe = '2>&1 1>/dev/null |tee'

  call gradle#logi("Compiling " . join(a:000, " "))

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

" Execute gradle vim task and load all information in memory dictionaries.
function! gradle#runVimTask()

  call gradle#logi("Runing vim gradle task. wait...")

  if !exists('g:gradle_jars')
    let g:gradle_jars = {}
  endif

  if !exists('g:target_versions')
    let g:gradle_target_versions = {}
  endif

  if !exists('g:gradle_project_names')
    let g:gradle_project_names = {}
  endif

  let l:gradleFile = gradle#findGradleFile()

  let l:result = system(gradle#bin() . " --no-color -b " . l:gradleFile . " vim")

  for line in split(l:result, '\n')
    let mlist = matchlist(line, '^vim-gradle\s\(.*\.jar\)$')
    if empty(mlist) == 0 && len(mlist[1]) > 0
      if !has_key(g:gradle_jars, l:gradleFile)
        let g:gradle_jars[l:gradleFile] = []
      endif
      call add(g:gradle_jars[l:gradleFile], mlist[1])
    endif

    let mlist = matchlist(line, '^vim-project\s\(.*\)$')
    if empty(mlist) == 0 && len(mlist[1]) > 0
      let g:gradle_project_names[l:gradleFile] = mlist[1]
    endif

    let mlist = matchlist(line, '^vim-target\s\(.*\)$')
    if empty(mlist) == 0 && len(mlist[1]) > 0
      let g:gradle_target_versions[l:gradleFile] = mlist[1]
    endif
  endfor

  call gradle#logi("Finished vim task ")

endfunction

function! gradle#loadGradleDeps()

  let l:gradleFile = gradle#findGradleFile()

  if !exists('g:gradle_jars') || !has_key(g:gradle_jars, l:gradleFile)
    call gradle#runVimTask()
  endif

  return g:gradle_jars[l:gradleFile]

endfunction

""
" Update the CLASSPATH environment variable to include all classes related to
" the current Android project.
function! gradle#setClassPath()

  let l:jarList = []
  let l:srcList = []

  let l:oldJars = split($CLASSPATH, ':')
  let l:oldSrcs = split($SRCPATH, ",")

  call extend(l:jarList, l:oldJars)
  call extend(l:srcList, l:oldSrcs)

  let l:depJars = gradle#loadGradleDeps()
  if !empty(l:depJars)
    call extend(l:jarList, l:depJars)
  endif

  let l:gradleSrcPaths = s:getGradleSrcPaths()
  if !empty(l:gradleSrcPaths)
    call extend(l:srcList, l:gradleSrcPaths)
  endif

  let l:jarList = gradle#uniq(sort(l:jarList))
  let l:srcList = gradle#uniq(sort(l:srcList))

  let $CLASSPATH = join(l:jarList, ':')
  let $SRCPATH = join(l:srcList, ':')

  exec "set path=" . join(l:srcList, ',')

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
" This gradle#uniq() function will use the built in uniq() function for vim >
" 7.4.218 and a custom implementation of older versions.
"
" NOTE: This method only works on sorted lists. If they are not sorted this will
" not result in a uniq list of elements!!
"
" Stolen from: https://github.com/LaTeX-Box-Team/LaTeX-Box/pull/223
function! gradle#uniq(list)

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

function! gradle#setupGradleCommands()
  command! -nargs=+ Gradle call gradle#compile(<f-args>)
endfunction
