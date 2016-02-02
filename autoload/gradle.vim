function! gradle#logi(msg)
  if exists('g:airline_initialized')
    let g:gradle_airline_status = a:msg
    call airline#update_statusline()
    redraw
  else
    redraw
    echomsg a:msg
  endif
endfunction

" Function that tries to determine the location of the gradle binary. It will
" try first to find the executable inside g:gradle_path and if not found it will
" try to search for the Gradle wrapper then try using the GRADLE_HOME 
" environment variable. Finally it will search if using the vim
" executable() method.
function! gradle#bin()

  if exists('g:gradle_path')
    let g:gradle_bin = g:gradle_path . "/bin/gradle"
  elseif gradle#getOS() == 'Windows' 
    if executable("\.gradlew.bat")
      let g:gradle_bin = "\.gradlew.bat"
    endif
  elseif executable("./gradlew")
    let g:gradle_bin = "./gradlew"
  elseif !exists('g:gradle_path')
    let g:gradle_path = $GRADLE_HOME
    let g:gradle_bin = g:gradle_path . "/bin/gradle"
  endif

  if(!executable(g:gradle_bin))
    if executable("gradle")
      let g:gradle_bin = "gradle"
    else
      echoerr "Gradle tool could not be found"
    endif
  endif

  return g:gradle_bin

endfunction

" Verifies if the android sdk is available and if the gradle build and binary
" are present.
function! gradle#isGradleProject()

  let l:gradle_cfg_exists = filereadable(gradle#findGradleFile())
  let l:gradle_bin_exists = executable(gradle#bin())

  if( ! l:gradle_cfg_exists )
    call gradle#logi("Gradle disabled")
    return 0
  endif

  if( ! l:gradle_bin_exists )
    call gradle#logi("Gradle disabled")
    return 0
  endif

  return 1
endfunction

" Function that compiles and installs the android app into a device.
" a:device is the device or emulator id as displayed by *adb devices* command.
" a:mode can be any of the compile modes supported by the build system (e.g.
" debug or release).
function! gradle#install(device, mode)
  let $ANDROID_SERIAL=a:device
  let l:result = call("gradle#run", ["install" . android#capitalize(a:mode)])
  call s:showQuickfix()
  call s:updateAirline(l:result[0], l:result[1])
  unlet $ANDROID_SERIAL
endfunction

function! gradle#uninstall(device, mode)
  let $ANDROID_SERIAL=a:device
  let l:result = call("gradle#run", ["uninstall" . android#capitalize(a:mode)])
  call s:showQuickfix()
  call s:updateAirline(l:result[0], l:result[1])
  unlet $ANDROID_SERIAL
endfunction

" Tries to determine the location of the build.gradle file starting from the
" current buffer location.
function! gradle#findGradleFile()

  let l:file = ""
  let l:path = expand("%:p:h")

  if len(l:path) <= 0
    let l:path = getcwd()
  endif

  let l:file = findfile("build.gradle", l:path . ";$HOME")

  if len(l:file) == 0
    return ""
  endif

  return copy(fnamemodify(l:file, ":p"))
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
  call gradle#logi("Gradle " . join(a:000, " "))
  let l:result = call("gradle#run", a:000)

  call s:showQuickfix()
  call s:updateAirline(l:result[0], l:result[1])
endfunction

function! gradle#run(...)

  call gradle#setCompiler()

  let shellpipe = &shellpipe

  let &shellpipe = '2>&1 1>/dev/null |tee'

  "if exists('g:loaded_dispatch')
  ""  silent! exe 'Make'
  "else
    execute("silent! make " . join(a:000, " "))
    redraw!
  "endif

  " Restore previous values
  let &shellpipe = shellpipe

  call gradle#cleanQuickFix()

  return [gradle#getErrorCount(), gradle#getWarningCount()]
endfunction

function! gradle#airlineErrorStatus()

  let l:errCount = gradle#getErrorCount()
  let l:warnCount = gradle#getWarningCount()

  if !exists('g:gradle_airline_error_glyph')
    let g:gradle_airline_error_glyph = "Error: "
  endif

  if !exists('g:gradle_airline_warning_glyph')
    let g:gradle_airline_warning_glyph = "Warning: "
  endif

  let l:errMsg = g:gradle_airline_error_glyph . '[' . l:errCount . ']'
  let l:warnMsg = g:gradle_airline_warning_glyph . '[' . l:warnCount . ']'

  if l:errCount > 0 && l:warnCount > 0
    return l:errMsg . " " . l:warnMsg
  elseif l:errCount > 0
    return l:errMsg
  elseif l:warnCount > 0
    return l:warnMsg
  else
    return ""
  endif

endfunction

function! gradle#airlineStatus()

  if exists('g:gradle_airline_status') && len(g:gradle_airline_status) > 0
    return android#glyph() . " " . g:gradle_airline_status
  else
    return android#glyph()
  end

endfunction

" Helper method to cleanup the qflist.
function! gradle#cleanQuickFix()
  let l:list = deepcopy(getqflist())
  call setqflist(filter(l:list, "v:val['text'] != 'Element SubscribeHandler unvalidated by '"))
endfunction

" This method returns the number of valid errors in the quickfix window. This
" allows us to check if there are errors after compilation.
function! gradle#getErrorCount()
  let l:list = deepcopy(getqflist())
  return len(filter(l:list, "v:val['valid'] > 0 && tolower(v:val['type']) != 'w'"))
endfunction

" This method returns the number of valid warnings in the quickfix window. This
" allows us to check if there are errors after compilation.
function! gradle#getWarningCount()
  let l:list = deepcopy(getqflist())
  return len(filter(l:list, "v:val['valid'] > 0 && tolower(v:val['type']) == 'w'"))
endfunction

" Execute gradle vim task and load all information in memory dictionaries.
function! gradle#runVimTask()

  call gradle#logi("Run vim task...")

  if !exists('g:gradle_jars')
    let g:gradle_jars = {}
  endif

  if !exists('g:gradle_target_versions')
    let g:gradle_target_versions = {}
  endif

  if !exists('g:gradle_project_names')
    let g:gradle_project_names = {}
  endif

  let l:gradleFile = gradle#findGradleFile()

  let l:cmd = [
   \ gradle#bin(),
   \ "--no-color",
   \ "-b",
   \ l:gradleFile,
   \ "-I",
   \ g:gradle_init_file,
   \ "vim"
   \ ]

  let l:result = system(join(l:cmd, ' '))

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

  call gradle#logi("")

endfunction

function! gradle#loadGradleDeps()

  let l:gradleFile = gradle#findGradleFile()

  if !exists('g:gradle_jars') || !has_key(g:gradle_jars, l:gradleFile)
    call gradle#runVimTask()
  endif

  if has_key(g:gradle_jars, l:gradleFile)
    return g:gradle_jars[l:gradleFile]
  else
    return []
  endif

endfunction

""
" Update the CLASSPATH environment variable to include all classes related to
" the current Android project.
function! gradle#setClassPath()

  if exists(":JCstart")
    return
  endif

  let l:jarList = []
  let l:srcList = []

  let l:oldJars = split($CLASSPATH, gradle#classPathSep())
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

  let $CLASSPATH = join(l:jarList, gradle#classPathSep())
  let $SRCPATH = join(l:srcList, gradle#classPathSep())

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

" Function tries to determine the OS that is running this plugin.
" http://vi.stackexchange.com/a/2577
function! gradle#getOS()

  if !exists('g:gradle_os')
    if has("win64") || has("win32") || has("win16")
      let g:gradle_os = "Windows"
    else
      let g:gradle_os = substitute(system('uname'), '\n', '', '')
    endif
  endif

  return g:gradle_os

endfunction

" Returns the classpath separator depending on the OS.
function! gradle#classPathSep()

  if !exists('g:gradle_sep')
    if gradle#getOS() == "Windows"
      let g:gradle_sep = ';'
    else
      let g:gradle_sep = ':'
    endif
  endif

  return g:gradle_sep

endfunction

function! gradle#setupGradleCommands()
  command! -nargs=+ Gradle call gradle#compile(<f-args>)
endfunction

function! s:showQuickfix()
  if !exists('g:gradle_quickfix_show')
    let g:gradle_quickfix_show = 1
  endif

  if g:gradle_quickfix_show
    execute('botright cwindow')
    " Work around bug that causes file to loose syntax after the quick fix
    " window is closed.
    if exists('g:syntax_on')
      execute('syntax enable')
    endif
  endif
endfunction

function! s:updateAirline(errorCount, warningCount)
  if exists("g:airline_initialized")
    call gradle#logi("")
  elseif a:errorCount > 0 || a:warningCount > 0
    call gradle#logi("Gradle Errors: " . a:errorCount . " Warnings: " . a:warningCount)
  endif
endfunction
