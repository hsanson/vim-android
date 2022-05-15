let s:chunks = {}
let s:lastOutput = []
let s:files = {}
let s:jobidseq = 0
let s:isBuilding = 0
let $LC_ALL='en_US.UTF8'

function! gradle#logi(msg)
  redraw
  echomsg a:msg
endfunction


" Returns the path to the gradle installation.
" TODO: The default works only in Linux OS.
function! gradle#gradleHome()

  if exists('$GRADLE_HOME')
    let g:gradle_path = $GRADLE_HOME
    return g:gradle_path
  endif

  if exists('g:gradle_path')
    return g:gradle_path
  endif

  let g:gradle_path = '/usr'
  return g:gradle_path

endfunction

function! gradle#wrapper()
  if gradle#getOS() ==# 'Windows' && executable('\.gradlew.bat')
    return fnamemodify('\.gradlew.bat', ':p')
  elseif executable('./gradlew')
    return fnamemodify('./gradlew', ':p')
  endif
endfunction


function! gradle#isExecutable(exec)
    if type(a:exec) != type('')
        return 0
    elseif strlen(a:exec) == 0
        return 0
    else
        return executable(a:exec)
    endif
endfunction

" Function that tries to determine the location of the gradle binary. If
" g:gradle_bin is defined then it is used as the gradle binary. If it is not
" defined and the project has a gradle wrapper script, then the wrapper script
" is used. If no wrapper script is found then the binary is searched in the
" gradle home directory if defined. Finally if none of the above works it tries
" to find gradle in the PATH and if that fails too then it is set to a non
" operation.
function! gradle#bin()

  if exists('g:gradle_bin')
    return g:gradle_bin
  endif

  if gradle#isExecutable(gradle#wrapper())
    let g:gradle_bin = gradle#wrapper()
    return g:gradle_bin
  endif

  if finddir(gradle#gradleHome()) !=# '' && gradle#isExecutable(gradle#gradleHome() . '/bin/gradle')
    let g:gradle_bin = gradle#gradleHome() . '/bin/gradle'
    return g:gradle_bin
  endif

  if executable('gradle')
    let g:gradle_bin = 'gradle'
    return g:gradle_bin
  endif

  return ''
endfunction

function! s:getGradleVersion()
  let l:cmd = join([gradle#bin(), ' --version'])
  let l:pattern = 'Gradle\s*\(\d\+\)\.\(\d\+\)'
  let l:result = system(l:cmd)
  let l:version_list = matchlist(l:result, l:pattern)

  if empty(l:version_list)
    return
  endif

  let l:version_major = l:version_list[1]
  let l:version_minor = l:version_list[2]
  let l:version = l:version_major . '.' . l:version_minor
  let l:cache_key = gradle#key(gradle#findGradleFile())
  call cache#set(l:cache_key, 'version', l:version)
  call cache#set(l:cache_key, 'version_major', l:version_major)
  call cache#set(l:cache_key, 'version_minor', l:version_minor)
endfunction

function! gradle#version()

  let l:key = gradle#key(gradle#findGradleFile())
  let l:gradle_version = cache#get(l:key, 'version', '')

  if l:gradle_version ==# ''
    call s:getGradleVersion()
  endif

  return cache#get(l:key, 'version', 'unknown')
endfunction

function! gradle#versionMajor()
  let l:key = gradle#key(gradle#findGradleFile())
  let l:gradle_version = cache#get(l:key, 'version_major', '')

  if l:gradle_version ==# ''
    call s:getGradleVersion()
  endif

  return str2nr(cache#get(l:key, 'version_major', ''))
endfunction

function! gradle#versionMinor()
  let l:key = gradle#key(gradle#findGradleFile())
  let l:gradle_version = cache#get(l:key, 'version_minor', '')

  if l:gradle_version ==# ''
    call s:getGradleVersion()
  endif

  return str2nr(cache#get(l:key, 'version_minor', ''))
endfunction

function! gradle#versionNumber()
  return gradle#versionMajor() * 100 + gradle#versionMinor()
endfunction

" Verifies if the android sdk is available and if the gradle build and binary
" are present.
function! gradle#isGradleProject()

  let l:gradle_cfg_exists = filereadable(gradle#findGradleFile())
  let l:gradle_bin_exists = gradle#isExecutable(gradle#bin())

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
  let l:result = call('gradle#run', ['install' . android#capitalize(a:mode)])
  let $ANDROID_SERIAL = l:old_serial
endfunction

function! gradle#build(mode)
  let l:result = call('gradle#run', ['assemble' . android#capitalize(a:mode)])
endfunction

function! gradle#uninstall(device, mode)
  let l:old_serial = $ANDROID_SERIAL
  let $ANDROID_SERIAL=a:device
  let l:result = call('gradle#run', ['uninstall' . android#capitalize(a:mode)])
  let $ANDROID_SERIAL = l:old_serial
endfunction

function! gradle#listVariants() abort
  let l:key = gradle#key(gradle#findGradleFile())
  let l:gradle_variants = cache#get(l:key, 'variants', '')

  if empty(l:gradle_variants)
    let l:result = system(join([gradle#bin(), ' -I ', g:gradle_init_file,' variants -q']))

    if empty(l:result)
      return
    endif

    call cache#set(l:key, 'variants', l:result)
  endif

  return cache#get(l:key, 'variants', '')
endfunction

" Return a unique key identifier for the gradle project. This key is generated
" based on the gradle file of the project, therefore it changes if the gradle
" file contents is changed.
function! gradle#key(path) abort
  return cache#key(a:path)
endfunction

" Tries to determine the location of the build.gradle file starting from the
" current buffer location.
function! gradle#findGradleFile()

  let l:file = ''
  let l:path = expand('%:p:h')

  if len(l:path) <= 0
    let l:path = getcwd()
  endif

  let l:file = findfile('build.gradle', l:path . ';$HOME')

  if len(l:file) == 0
    let l:file = findfile('build.gradle.kts', l:path . ';$HOME')
  endif

  if len(l:file) == 0
    return ''
  endif

  return copy(fnamemodify(l:file, ':p'))
endfunction

" Tries to find the root of the android project. It uses the build.gradle file
" location as root. This allows vim-android to work with multi-project
" environments.
function! gradle#findRoot()
  return fnamemodify(gradle#findGradleFile(), ':p:h')
endfunction

function! gradle#isCompilerSet()
  if(exists('b:current_compiler') && b:current_compiler ==# 'gradle')
    return 1
  else
    return 0
  endif
endfunction

function! gradle#compile(...)
  call gradle#logi('Gradle ' . join(a:000, ' '))
  let l:result = call('gradle#run', a:000)
endfunction

function! s:BufWinId() abort
    return exists('*bufwinid') ? bufwinid(str2nr(bufnr('%'))) : 0
endfunction

function! gradle#cmd(...) abort
  let l:cmd = efm#cmd()
  let l:cmd = extend(l:cmd, a:000)
  let l:cmd = extend(l:cmd, efm#shellpipe())
  return l:cmd
endfunction

function! gradle#glyph()
  if !exists('g:gradle_glyph_gradle')
    let g:gradle_glyph_gradle = 'G'
  endif
  return g:gradle_glyph_gradle
endfunction

function! gradle#glyphError()
  if !exists('g:gradle_glyph_error')
    let g:gradle_glyph_error = 'E'
  endif
  return g:gradle_glyph_error
endfunction

function! gradle#glyphWarning()
  if !exists('g:gradle_glyph_warning')
    let g:gradle_glyph_warning = 'W'
  endif
  return g:gradle_glyph_warning
endfunction

function! gradle#glyphBuilding()
  if !exists('g:gradle_glyph_building')
    let g:gradle_glyph_building = 'B'
  endif
  return g:gradle_glyph_building
endfunction

function! gradle#asyncEnable()
  let g:gradle_async = 1
endfunction

function! gradle#asyncDisable()
  let g:gradle_async = 0
endfunction

function! gradle#showSigns()
  if !exists('g:gradle_show_signs')
    if exists('g:loaded_ale')
      let g:gradle_show_signs = 0
    else
      let g:gradle_show_signs = 1
    end
  endif
  return g:gradle_show_signs
endfunction

function! gradle#syncOnLoad()
  if !exists('g:gradle_sync_on_load')
    let g:gradle_sync_on_load = 1
  endif
  return g:gradle_sync_on_load
endfunction

function! gradle#isAsyncEnabled()
  if !exists('g:gradle_async')
    let g:gradle_async = 1
  endif
  return g:gradle_async
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

function! gradle#glyphProject()
  if(android#isAndroidProject())
    return android#glyph()
  elseif(gradle#isGradleProject())
    return gradle#glyph()
  endif
endfunction

" Deprecated.
function! gradle#statusLine()
  return join([
        \ lightline#gradle#running(),
        \ lightline#gradle#errors(),
        \ lightline#gradle#warnings(),
        \ lightline#gradle#project()
        \], ' ')
endfunction

function! gradle#jobCount() abort
  return gradle#running() ? s:isBuilding : 0
endfunction

function! gradle#running() abort
  return exists('s:isBuilding') && s:isBuilding > 0
endfunction

" This method returns the number of valid errors in the loclist. This
" allows us to check if there are errors after compilation.
function! gradle#getErrorCount()
  let l:id = s:BufWinId()
  let l:list = deepcopy(getloclist(l:id))
  return len(filter(l:list, "v:val['valid'] > 0 && tolower(v:val['type']) ==# 'e'"))
endfunction

" This method returns the number of valid warnings in the loclist window. This
" allows us to check if there are errors after compilation.
function! gradle#getWarningCount()
  let l:id = s:BufWinId()
  let l:list = deepcopy(getloclist(l:id))
  return len(filter(l:list, "v:val['valid'] > 0 && tolower(v:val['type']) ==# 'w'"))
endfunction

function! gradle#syncCmd()
  return [
   \ gradle#bin(),
   \ '-b',
   \ gradle#findGradleFile(),
   \ '-I',
   \ g:gradle_init_file,
   \ 'vim'
   \ ]
endfunction

function! gradle#run(...)

  let l:cmd = call('gradle#cmd', a:000)

  if gradle#isAsyncEnabled() && has('nvim') && exists('*jobstart')
    call s:nvim_job(l:cmd)
  elseif gradle#isAsyncEnabled() && exists('*job_start')
    call s:vim_job(l:cmd)
  else
    let l:gradleFile = gradle#findGradleFile()
    let l:result = split(system(join(l:cmd, ' ')), '\n')
    let l:id = s:BufWinId()
    call setloclist(l:id, [], ' ', s:What(l:result))
    redraw!
    call s:showLoclist()
  endif

  return [gradle#getErrorCount(), gradle#getWarningCount()]

endfunction


" Sync vim-android environment with build.gradle file.
function! gradle#sync() abort
  if gradle#isAsyncEnabled() && has('nvim') && exists('*jobstart')
    call s:nvim_job(gradle#syncCmd())
  elseif gradle#isAsyncEnabled() && exists('*job_start')
    call s:vim_job(gradle#syncCmd())
  else
   let l:gradleFile = gradle#findGradleFile()
    call gradle#logi('Gradle sync, please wait...')
    let l:result = split(system(join(gradle#syncCmd(), ' ')), '\n')
    call s:parseVimTaskOutput(l:gradleFile, l:result)
    let l:id = s:BufWinId()
    call setloclist(l:id, [], ' ', s:What(l:result))
    call s:setClassPath()
    call gradle#logi('')
    call ale_linters#java#NotifyConfigChange()
  endif
endfunction

function! s:parseVimTaskOutput(gradleFile, result)

  for line in a:result

    let mlist = matchlist(line, '^vim-builddir\s\(.*\)$')
    if empty(mlist) == 0 && len(mlist[1]) > 0 && isdirectory(mlist[1])
      call add(cache#get(gradle#key(a:gradleFile), 'jars', []), mlist[1])
    endif

    let mlist = matchlist(line, '^vim-src\s\(.*\)$')
    if empty(mlist) == 0 && len(mlist[1]) > 0 && isdirectory(mlist[1])
      call add(cache#get(gradle#key(a:gradleFile), 'srcs', []), mlist[1])
    endif

    let mlist = matchlist(line, '^vim-gradle\s\(.*\)$')
    if empty(mlist) == 0 && len(mlist[1]) > 0
      call add(cache#get(gradle#key(a:gradleFile), 'jars', []), mlist[1])
    endif

    let mlist = matchlist(line, '^vim-project\s\(.*\)$')
    if empty(mlist) == 0 && len(mlist[1]) > 0
      call cache#set(gradle#key(a:gradleFile), 'name', mlist[1])
    endif

    let mlist = matchlist(line, '^vim-target\s\(.*\)$')
    if empty(mlist) == 0 && len(mlist[1]) > 0
      call cache#set(gradle#key(a:gradleFile), 'target', mlist[1])
    endif

  endfor

endfunction

function! gradle#projectName() abort
  return cache#get(gradle#key(gradle#findGradleFile()), 'name', '')
endfunction

function! gradle#targetVersion() abort
  return cache#get(gradle#key(gradle#findGradleFile()), 'target', 'android-28')
endfunction

""
" Return the gradle dependencies per project from the cache if available or an
" empty array if not available.
function! gradle#classPaths() abort
  return cache#get(gradle#key(gradle#findGradleFile()), 'jars', [])
endfunction

""
" Return the gradle source pahts per  project from the cache if available or an
" empty array otherwise.
function! gradle#sourcePaths() abort
  return cache#get(gradle#key(gradle#findGradleFile()), 'srcs', [])
endfunction

""
" Returns 1 if the project jar dependencies are changed or 0 otherwise.
function! gradle#isGradleDepsCached()
  return !empty(gradle#classPaths())
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
    if has('win64') || has('win32') || has('win16')
      let g:gradle_os = 'Windows'
    else
      let g:gradle_os = substitute(system('uname'), '\n', '', '')
    endif
  endif

  return g:gradle_os

endfunction

" Returns the classpath separator depending on the OS.
function! gradle#classPathSep()

  if !exists('g:gradle_sep')
    if gradle#getOS() ==# 'Windows'
      let g:gradle_sep = ';'
    else
      let g:gradle_sep = ':'
    endif
  endif

  return g:gradle_sep

endfunction

function! gradle#setupGradleCommands()
  if gradle#isExecutable(gradle#bin())
    command! -nargs=+ Gradle call gradle#compile(<f-args>)
    command! GradleSync call gradle#sync()
    command! GradleInfo call gradle#output()
    command! GradleGenClassPathFile call classpath#generateClasspath()
  else
    command! -nargs=? Gradle echoerr 'Gradle binary could not be found, vim-android gradle commands are disabled'
    command! GradleSync echoerr 'Gradle binary could not be found, vim-android gradle commands are disabled'
    command! GradleInfo echoerr 'Gradle binary could not be found, vim-android gradle commands are disabled'
  endif
endfunction

function! s:showSigns()

  if ! gradle#showSigns()
    return
  endif

  execute('sign unplace *')
  execute('sign define gradleErrorSign text=' . gradle#glyphError() . ' texthl=Error')
  execute('sign define gradleWarningSign text=' . gradle#glyphWarning() . ' texthl=Warning')
  let l:id = s:BufWinId()
  for item in getloclist(l:id)
    if item.valid && item.bufnr != 0 && item.lnum > 0
      let l:signId = s:lpad(item.bufnr) . s:lpad(item.lnum)
      let l:sign = 'sign place ' . l:signId . ' line=' . item.lnum
      if item.type ==# 'e'
        let l:sign = l:sign . ' name=gradleErrorSign'
      else
        let l:sign = l:sign . ' name=gradleWarningSign'
      endif
      let l:sign = l:sign . ' buffer=' . item.bufnr
      execute(l:sign)
    endif
  endfor
endfunction

function! s:showLoclist()

  " Backward compatibility
  if !exists('g:gradle_quickfix_show')
    let g:gradle_quickfix_show = 0
  endif

  if !exists('g:gradle_loclist_show')
    let g:gradle_loclist_show = g:gradle_quickfix_show
  endif

  call s:showSigns()

  if !g:gradle_loclist_show
    return
  end

  if gradle#getErrorCount() > 0
    execute('botright lopen | wincmd p')
  else
    execute('lclose')
    " Work around bug that causes file to loose syntax after the quick fix
    " window is closed.
    if exists('g:syntax_on')
      execute('syntax enable')
    endif
  endif
endfunction

" Add left zero padding to input number.
"   call s:lpad(20) -> 00020
function! s:lpad(s)
  return repeat('0', 5 - len(a:s)) . a:s
endfunction

function! s:What(result) abort
    return {
    \ 'nr': '$',
    \ 'efm': efm#escape(efm#efm()),
    \ 'lines': a:result,
    \ 'title': 'gradle'
    \}
endfunction

function! s:updateLightline() abort
  if exists('*lightline#update')
    call lightline#update()
  endif
endfunction

function! s:startBuilding()
  let s:isBuilding = s:isBuilding + 1
  call s:updateLightline()
endfunction

function! s:finishBuilding()
  let s:isBuilding = s:isBuilding - 1
  call s:updateLightline()
endfunction

function! s:out_cb(chid, id, data) abort
  call s:job_cb(a:chid, split(a:data, "\n", 1), 'stdout')
endfunction

function! s:err_cb(chid, id, data) abort
  call s:job_cb(a:chid, split(a:data, "\n", 1), 'stderr')
endfunction

function! s:exit_cb(chid, id, status) abort
  call s:job_cb(a:chid, a:status, 'exit')
endfunction

function! gradle#output()
  if gradle#running()
    echom 'Gradle still running'
  else
    for l:line in s:lastOutput
      echom l:line
    endfor
  endif
endfunction

" Callback invoked when the gradle#sync() method finishes processing. Used when
" using nvim async functionality.
function! s:job_cb(id, data, event) abort

  if (a:event ==# 'stdout' || a:event ==# 'stderr') && !empty(a:data)
    let s:chunks[a:id][-1] .= a:data[0]
    call extend(s:chunks[a:id], a:data[1:])
  elseif a:event ==# 'exit'
    call s:parseVimTaskOutput(s:files[a:id], s:chunks[a:id])
    let l:id = s:BufWinId()
    call setloclist(l:id, [], ' ', s:What(s:chunks[a:id]))
    let s:lastOutput = deepcopy(s:chunks[a:id])
    call remove(s:chunks, a:id)
    call s:showLoclist()
    call s:setClassPath()
    call s:finishBuilding()
    call ale_linters#java#NotifyConfigChange()
  endif
endfunction

function! s:nvim_job(cmd) abort

  let l:gradleFile = gradle#findGradleFile()

  let l:options = {
        \ 'on_stdout': function('s:job_cb'),
        \ 'on_stderr': function('s:job_cb'),
        \ 'on_exit':   function('s:job_cb')
        \ }

  call s:startBuilding()

  let l:ch = jobstart(join(a:cmd), l:options)
  let s:chunks[l:ch] = ['']
  let s:files[l:ch] = l:gradleFile
endfunction

function! s:vim_job(cmd) abort

  let l:gradleFile = gradle#findGradleFile()
  let s:jobidseq = s:jobidseq + 1
  let l:ch = s:jobidseq

  let l:options = {
      \ 'out_cb': function('s:out_cb', [l:ch]),
      \ 'err_cb': function('s:err_cb', [l:ch]),
      \ 'exit_cb': function('s:exit_cb', [l:ch]),
      \ 'mode': 'raw'
      \ }

  if has('patch-8.1.889')
    let l:options['noblock'] = 1
  endif

  let s:chunks[l:ch] = ['']
  let s:files[l:ch] = l:gradleFile
  call s:startBuilding()
  call job_start(a:cmd, l:options)
endfunction

" Helper method to setup all gradle/android environments. This task must be
" called only after the gradle#sync() method finishes and the dependencies are
" already cached.
function! s:setClassPath() abort

  if !exists('g:gradle_set_classpath')
    let g:gradle_set_classpath = 1
  endif

  if g:gradle_set_classpath != 1
    return
  endif

  let l:deps = gradle#classPaths()
  let l:srcs = extend(gradle#sourcePaths(), android#sourcePaths())
  let $CLASSPATH = join(gradle#uniq(sort(l:deps)), gradle#classPathSep())
  let $SRCPATH = join(gradle#uniq(sort(l:srcs)), gradle#classPathSep())
  exec 'set path=' . join(gradle#uniq(sort(l:srcs)), gradle#classPathSep())

  " [LEGACY] Is recommended to use ALE plugin with javalsp linter instead of
  " javacomplete plugin.
  if exists('*javacomplete#SetClassPath')
    call javacomplete#SetClassPath($CLASSPATH)
  endif

  " [LEGACY] Is recommended to use ALE plugin with javalsp linter instead of
  " javacomplete plugin.
  if exists('*javacomplete#SetSourcePath')
    call javacomplete#SetSourcePath($SRCPATH)
  endif

  " [LEGACY] Is recommended to use ALE plugin with javalsp linter instead of
  " syntastic plugin.
  let g:syntastic_java_javac_classpath = $CLASSPATH . ':' . $SRCPATH

endfunction
