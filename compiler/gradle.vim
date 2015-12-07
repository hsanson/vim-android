let current_compiler = 'gradle'

if exists(":CompilerSet") != 2 " for older vims
  command -nargs=* CompilerSet setlocal <args>
endif

" Links to understand error formats
"   http://flukus.github.io/2015/07/03/2015_07_03-Vim-errorformat-Demystified/

let s:makeprg = [
 \  gradle#bin(),
 \  '--no-color',
 \  '-I',
 \  g:gradle_init_file,
 \  '-b',
 \  gradle#findGradleFile()
 \ ]

exec 'CompilerSet makeprg=' . join(s:makeprg, '\ ')

CompilerSet errorformat=\%+GTask\ %.%#\ not\ found\ %.%#.,
                       \%-G%f:%l:\ %tarning:\ Element\ SubscribeHandler\ unvalidated\ %.%#,
                       \%+Gcom.android.ddmlib.InstallException:\ %m,
                       \%W\findbugs:\ %tarning\ %f:%l:%c\ %m,
                       \%W\pmd:\ %tarning\ %f:%l:%c\ %m,
                       \%W\checkstyle:\ %tarning\ %f:%l:%c\ %m,
                       \%W\lint:\ %tarning\ %f:%l:%c\ %m,
                       \%E\lint:\ %trror\ %f:%l:%c\ %m,
                       \%E>\ %f:%l:%c:\ %trror:\ %m,
                       \%W>\ %f:%l:%c:\ %tarning:\ %m,
                       \%E%f:%l:\ %trror:\ %m,
                       \%W%f:%l:\ %tarning:\ %m,
                       \%Z%p%*[%^~],
                       \%C%.%#

