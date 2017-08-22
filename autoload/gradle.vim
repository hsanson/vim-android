function! gradle#logi(msg)
  redraw
  echomsg a:msg
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
    endif
  endif

  return g:gradle_bin

endfunction

function! gradle#version()
  if exists('g:gradle_versions[gradle#findGradleFile()]')
    return g:gradle_versions[gradle#findGradleFile()][0]
  endif
endfunction

function! gradle#versionMajor()
  if exists('g:gradle_versions[gradle#findGradleFile()]')
    return g:gradle_versions[gradle#findGradleFile()][1]
  endif
endfunction

function! gradle#versionMinor()
  if exists('g:gradle_versions[gradle#findGradleFile()]')
    return g:gradle_versions[gradle#findGradleFile()][2]
  endif
endfunction

" Verifies if the android sdk is available and if the gradle build and binary
" are present.
function! gradle#isGradleProject()

  let l:gradle_cfg_exists = filereadable(gradle#findGradleFile())
  let l:gradle_bin_exists = executable(gradle#bin())

  if( ! l:gradle_cfg_exists )
    return 0
  endif

  if( ! l:gradle_bin_exists )
    return 0
  endif

  return 1
endfunction

" Function that compiles and installs the android app into a device.
" a:device is the device or emulator id as displayed by *adb devices* command.
" a:mode can be any of the compile modes supported by the build system (e.g.
" debug or release).
function! gradle#install(device, mode)
  let l:old_serial = $ANDROID_SERIAL
  let $ANDROID_SERIAL=a:device
  let l:result = call("gradle#run", ["install" . android#capitalize(a:mode)])
  let $ANDROID_SERIAL = l:old_serial
endfunction

function! gradle#uninstall(device, mode)
  let l:old_serial = $ANDROID_SERIAL
  let $ANDROID_SERIAL=a:device
  let l:result = call("gradle#run", ["uninstall" . android#capitalize(a:mode)])
  let $ANDROID_SERIAL = l:old_serial
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
endfunction

function! gradle#run(...)

  let shellpipe = &shellpipe
  let &shellpipe = '2>&1 1>/dev/null |tee'

  call s:startBuilding()

  if gradle#isAsyncEnabled()
    let s:errorfile = tempname()
    let s:callbacks = {
          \ 'on_stdout': function('s:runHandler'),
          \ 'on_stderr': function('s:runHandler'),
          \ 'on_exit':   function('s:runHandler'),
          \ 'errorfile': s:errorfile
          \ }
    execute("compiler gradle")
    let l:cmd = &makeprg . ' ' . join(a:000, ' ') . ' ' . &shellpipe . ' ' . s:errorfile
    let vimTaskJob = jobstart(l:cmd, s:callbacks)
  else
    execute("compiler gradle | silent! make " . join(a:000, " "))
    call s:finishBuilding()
    redraw!
    call s:showQuickfix()
  endif

  let &shellpipe = shellpipe

  return [gradle#getErrorCount(), gradle#getWarningCount()]

endfunction

function! s:runHandler(id, data, event) dict
  if a:event == 'exit'
    call s:finishBuilding()
    execute('cgetfile ' . self.errorfile)
    call s:showQuickfix()
  endif
endfunction

function! gradle#glyph()
  if !exists('g:gradle_glyph_gradle')
    let g:gradle_glyph_gradle = "G"
  endif
  return g:gradle_glyph_gradle
endfunction

function! gradle#glyphError()
  if !exists('g:gradle_glyph_error')
    let g:gradle_glyph_error = "E"
  endif
  return g:gradle_glyph_error
endfunction

function! gradle#glyphWarning()
  if !exists('g:gradle_glyph_warning')
    let g:gradle_glyph_warning = "W"
  endif
  return g:gradle_glyph_warning
endfunction

function! gradle#glyphBuilding()
  if !exists('g:gradle_glyph_building')
    let g:gradle_glyph_building = "building..."
  endif
  return g:gradle_glyph_building
endfunction

function! gradle#asyncEnable()
  let g:gradle_async = 1
endfunction

function! gradle#asyncDisable()
  let g:gradle_async = 0
endfunction

function! gradle#isAsyncEnabled()
  if !exists('g:gradle_async')
    let g:gradle_async = 1
  endif
  return has('nvim') && exists('*jobstart') && g:gradle_async
endfunction

function! gradle#asyncToggle()
  if gradle#isAsyncEnabled()
    call gradle#asyncDisable()
  else
    call gradle#asyncEnable()
  endif
endfunction

function! gradle#isDaemonEnabled()
  if !exists('g:gradle_daemon')
    let g:gradle_daemon = 1
  endif
  return g:gradle_daemon
endfunction

function! gradle#statusLineError()

  let l:errCount = gradle#getErrorCount()
  let l:warnCount = gradle#getWarningCount()

  let l:errMsg = l:errCount . gradle#glyphError()
  let l:warnMsg = l:warnCount . gradle#glyphWarning()

  if l:errCount > 0 && l:warnCount > 0
    return l:errMsg . ' ' . l:warnMsg
  elseif l:errCount > 0
    return l:errMsg
  elseif l:warnCount > 0
    return l:warnMsg
  else
    return ""
  endif

endfunction

function! gradle#glyphProject()
  if(android#isAndroidProject())
    return android#glyph()
  elseif(gradle#isGradleProject())
    return gradle#glyph()
  endif
endfunction

function! gradle#statusLine()
  if s:isBuilding()
    return gradle#glyphProject() . ' ' . gradle#glyphBuilding()
  else
    return gradle#glyphProject() . ' ' . gradle#statusLineError()
  endif
endfunction

function! s:isBuilding()
  return exists('s:isBuilding') && s:isBuilding > 0
endfunction

function! s:startBuilding()
  if ! exists('s:isBuilding')
    let s:isBuilding = 0
  endif
  let s:isBuilding = s:isBuilding + 1
endfunction

function! s:finishBuilding()
  if ! exists('s:isBuilding')
    let s:isBuilding = 0
  endif
  let s:isBuilding = s:isBuilding - 1
endfunction

" Helper method to cleanup the qflist.
function! s:cleanQuickFix()
  let l:list = deepcopy(getqflist())
  call setqflist(filter(l:list, "v:val['text'] != 'Element SubscribeHandler unvalidated by '"))
endfunction

" This method returns the number of valid errors in the quickfix window. This
" allows us to check if there are errors after compilation.
function! gradle#getErrorCount()
  let l:list = deepcopy(getqflist())
  return len(filter(l:list, "v:val['valid'] > 0 && tolower(v:val['type']) == 'e'"))
endfunction

" This method returns the number of valid warnings in the quickfix window. This
" allows us to check if there are errors after compilation.
function! gradle#getWarningCount()
  let l:list = deepcopy(getqflist())
  return len(filter(l:list, "v:val['valid'] > 0 && tolower(v:val['type']) == 'w'"))
endfunction

function! gradle#syncCmd()
  let l:cmd = [
   \ gradle#bin(),
   \ "-b",
   \ gradle#findGradleFile(),
   \ "-I",
   \ g:gradle_init_file,
   \ "vim"
   \ ]

  return join(l:cmd, ' ')
endfunction

" Sync vim-android environment with build.gradle file.
function! gradle#sync()

  if !exists('g:gradle_jars')
    let g:gradle_jars = {}
  endif

  if !exists('g:gradle_target_versions')
    let g:gradle_target_versions = {}
  endif

  if !exists('g:gradle_project_names')
    let g:gradle_project_names = {}
  endif

  if !exists('g:gradle_versions')
    let g:gradle_versions = {}
  endif

  let l:gradleFile = gradle#findGradleFile()

  call s:startBuilding()

  if gradle#isAsyncEnabled()
    let s:callbacks = {
          \ 'on_stdout': function('s:vimTaskHandler'),
          \ 'on_stderr': function('s:vimTaskHandler'),
          \ 'on_exit':   function('s:vimTaskHandler'),
          \ 'gradleFile': l:gradleFile
          \ }

    let vimTaskJob = jobstart(gradle#syncCmd(), s:callbacks)
  else
    call gradle#logi("Gradle sync, please wait...")
    let l:result = system(gradle#syncCmd())
    call s:parseVimTaskOutput(l:gradleFile, split(l:result, "\n"))
    call gradle#setup()
    call gradle#logi("")
    call s:finishBuilding()
  endif

endfunction

" Helper method to setup all gradle/android environments. This task must be
" called only after the gradle#sync() method finishes and the dependencies are
" already cached.
function! gradle#setup()

  if !exists('g:gradle_set_classpath')
    let g:gradle_set_classpath = 1
  endif

  if g:gradle_set_classpath != 1
    return
  endif

  call gradle#setClassPath()

  if android#isAndroidProject()
    call android#setAndroidSdkTags()
    call android#setClassPath()
  endif

  silent! call javacomplete#SetClassPath($CLASSPATH)
  silent! call javacomplete#SetSourcePath($SRCPATH)

  let g:syntastic_java_javac_classpath = $CLASSPATH . ":" . $SRCPATH

endfunction

" Callback invoked when the gradle#sync() method finishes processing. Used when
" using nvim async functionality.
function! s:vimTaskHandler(id, data, event) dict

  if a:event == 'stdout' || a:event == 'stderr'
    call s:parseVimTaskOutput(self.gradleFile, a:data)
  elseif a:event == 'exit'
    call s:finishBuilding()
    if a:data != 0
      call gradle#logi("Gradle sync task failed")
    endif
    call gradle#setup()
  endif
endfunction

function! s:parseVimTaskOutput(gradleFile, result)
  for line in a:result

    let mlist = matchlist(line, '^gradle-version\s\(\d\+\)\.\(\d\+\).*$')
    if empty(mlist) == 0
      let g:gradle_versions[a:gradleFile] = copy(mlist)
    endif

    let mlist = matchlist(line, '^vim-gradle\s\(.*\.jar\)$')
    if empty(mlist) == 0 && len(mlist[1]) > 0
      if !has_key(g:gradle_jars, a:gradleFile)
        let g:gradle_jars[a:gradleFile] = []
      endif
      call add(g:gradle_jars[a:gradleFile], mlist[1])
    endif

    let mlist = matchlist(line, '^vim-project\s\(.*\)$')
    if empty(mlist) == 0 && len(mlist[1]) > 0
      let g:gradle_project_names[a:gradleFile] = mlist[1]
    endif

    let mlist = matchlist(line, '^vim-target\s\(.*\)$')
    if empty(mlist) == 0 && len(mlist[1]) > 0
      let g:gradle_target_versions[a:gradleFile] = mlist[1]
    endif
  endfor
endfunction

""
" Return the gradle dependencies per project from the cache if available or an
" empty array if not available.
function! gradle#getGradleDeps()

  let l:gradleFile = gradle#findGradleFile()

  if has_key(g:gradle_jars, l:gradleFile)
    return g:gradle_jars[l:gradleFile]
  else
    return []
  endif

endfunction

""
" Returns 1 if the project jar dependencies are changed or 0 otherwise.
function! gradle#isGradleDepsCached()
  let l:gradleFile = gradle#findGradleFile()
  if !exists('g:gradle_jars')
    let g:gradle_jars = {}
  endif
  return has_key(g:gradle_jars, l:gradleFile)
endfunction

""
" Update the CLASSPATH environment variable to include all classes related to
" the current Android project.
function! gradle#setClassPath()

  let l:jarList = []
  let l:srcList = []

  let l:oldJars = split($CLASSPATH, gradle#classPathSep())
  let l:oldSrcs = split($SRCPATH, ",")

  call extend(l:jarList, l:oldJars)
  call extend(l:srcList, l:oldSrcs)

  let l:depJars = gradle#getGradleDeps()
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
  if executable(gradle#bin())
    command! -nargs=+ Gradle call gradle#compile(<f-args>)
    command! GradleSync call gradle#sync()
  else
    command! -nargs=? Gradle echoerr "Gradle binary could not be found, vim-android gradle commands are disabled"
    command! GradleSync echoerr "Gradle binary could not be found, vim-android gradle commands are disabled"
  endif
endfunction

function! s:showSigns()

  execute("sign unplace *")
  execute("sign define gradleErrorSign text=" . gradle#glyphError() . " texthl=Error")
  execute("sign define gradleWarningSign text=" . gradle#glyphWarning() . " texthl=Warning")
  for item in getqflist()
    if item.valid
      let l:signId = s:lpad(item.bufnr) . s:lpad(item.lnum)
      let l:sign = "sign place " . l:signId . " line=" . item.lnum
      if item.type == 'e'
        let l:sign = l:sign . " name=gradleErrorSign"
      else
        let l:sign = l:sign . " name=gradleWarningSign"
      endif
      let l:sign = l:sign . " buffer=" . item.bufnr
      execute(l:sign)
    endif
  endfor
endfunction

function! s:showQuickfix()

  if !exists('g:gradle_quickfix_show')
    let g:gradle_quickfix_show = 1
  endif

  call s:cleanQuickFix()
  call s:showSigns()

  if g:gradle_quickfix_show
    if gradle#getErrorCount() > 0
      execute('botright copen | wincmd p')
    else
      execute('cclose')
      " Work around bug that causes file to loose syntax after the quick fix
      " window is closed.
      if exists('g:syntax_on')
        execute('syntax enable')
      endif
    endif
  endif
endfunction

" Add left zero padding to input number.
"   call s:lpad(20) -> 00020
function! s:lpad(s)
  return repeat('0', 5 - len(a:s)) . a:s
endfunction
