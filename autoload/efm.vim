function! efm#cmd() abort
  let l:makeprg = [
   \  escape(gradle#bin(), ' '),
   \  '-I',
   \  g:gradle_init_file,
   \  '-b',
   \  escape(gradle#findGradleFile(), ' ')
   \ ]

  if gradle#isDaemonEnabled()
    call add(l:makeprg, '--daemon')
  else
    call add(l:makeprg, '--no-daemon')
  endif

  if gradle#versionNumber() >= 203
    call add(l:makeprg, '--console')
    call add(l:makeprg, 'plain')
  else
    call add(l:makeprg, '--no-color')
  endif

  return l:makeprg
endfunction

function! efm#makeprg()
  return join(efm#cmd(), '\ ')
endfunction

" Builds and returns the shellpipe used when runing the gradle compiler.
" TODO: Win and Mac support?
function! efm#shellpipe()
  return [
   \ '2>&1',
   \ '|',
   \ g:gradle_efm_sanity,
   \ '|',
   \ 'tee'
   \ ]
endfunction

" Ultimate errorformat string for Gradle development. It supports several
" plugins, compilers, linters and checkers.
"
" Links to understand error formats
"   https://flukus.github.io/vim-errorformat-demystified.html
"   http://qiita.com/rbtnn/items/92f80d53803ce756b4b8  (In Japanese)
"   https://vi.stackexchange.com/questions/4048/vim-errorformat-question-for-gradle-compiler-plugin/4052
"
" TODO: Cannot make the java errors column number get detected with the %p^
" pattern.
function! efm#efm()
  let efm='%-G:%.%#,'                          " Filter out everything that starts with :
  let efm.='%-GNote:%.%#,'                     " Filter out everything that starts with Note:
  let efm.='%-G  warning:%.%#,'
  let efm.='%Wwarning: %m,'
  let efm.='findbugs: %tarning %f:%l:%c %m,'   " Find bugs
  let efm.='pmd: %tarning %f:%l:%c %m,'        " PMD
  let efm.='checkstyle: %tarning %f:%l:%c %m,' " Checkstyle
  let efm.='lint: %tarning %f:%l:%c %m,'       " Linter
  let efm.='%f:%l:%c: %trror: %m,'             " single aapt
  let efm.='%f:%l:%c: %tarning: %m,'           " single aapt
  let efm.='%EFAILURE: %m,'                    " Catch all exception start
  let efm.='%-ZBUILD FAILED,'                  " Catch all exception end
  let efm.='%Ee: %f:%l: error: %m,'
  let efm.='%Ww: %f:%l: warning: %m,'
  let efm.='%E%f:%l: error: %m,'
  let efm.='%W%f:%l: warning: %m,'
  let efm.='%W%f:%l:%c-%.%# Warning: %m,'      " multi manifest start
  let efm.='%E%f:%l:%c-%.%# Error: %m,'        " multi manifest start
  let efm.='%C%.%#%p^,'
  let efm.='%+Ie:  %.%#,'
  let efm.='%+Iw:  %.%#,'
  let efm.='%+I  %.%#,'
  let efm.='%t: %f: (%l\, %c): %m,'           " single Kotlin
  let efm.='%t: %f: %m,'                       " single Kotlin
  let efm.='%-G%.%#'                           " Remove not matching messages
  return efm
endfunction

" Trying to write errorformat strings with included escaping is extremely
" confusing and not recommended. Better write them normally and then escape them
" before passing them to the setlocal or SetCompiler commands.
function! efm#escape(efm)
  return substitute(substitute(a:efm, '\', '\\\\', 'g'), ' ', '\\\ ', 'g')
endfunction

" Simple function to test errorformat matches. Used mostly for unit testing
" via vim-vader.
" 
" Example:
"
"    call gradle#testErf("kotlin.efm")
"
" To see the list of error output samples see the test/efm folder. To
" add more samples simply add them to this folder.
function! efm#test(testFile)
  let tmpEfm = &errorformat
  try
    execute('setlocal errorformat=' . efm#escape(efm#efm()))
    execute('cgetfile ' . g:gradle_test_dir . '/efm/' . a:testFile)
    copen
  catch
    echo v:exception
    echo v:throwpoint
  finally
    let &errorformat=tmpEfm
  endtry
endfunction

" Simple function to test errorformat strings. Used to debug and build
" new errorformat matches.
" 
" Example:
"
"    call gradle#testSingleErf("%t: %f: (%l\\, %c): %m", "kotlin.efm")
"
" The first argument is the errorformat string to test and the
" second argument is a filename of the file that contains the error
" output to test.
"
" To see the list of error output samples see the test/efm folder. To
" add more samples simply add them to this folder.
function! efm#testSingle(fmt, testFile)
  let tmpEfm = &errorformat
  try
    execute('setlocal errorformat=' .efm#escapeEfm(a:fmt))
    execute('cgetfile ' . g:gradle_test_dir . '/efm/' . a:testFile)
    copen
  catch
    echo v:exception
    echo v:throwpoint
  finally
    let &errorformat=tmpEfm
  endtry
endfunction

