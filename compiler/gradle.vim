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

CompilerSet errorformat=\%-G%f:%l:\ %tarning:\ Element\ SubscribeHandler\ unvalidated\ %.%#,
                        \[ant:checkstyle\]\ %f:%l:%c:\ %m,
                        \[ant:checkstyle\]\ %f:%l:\ %m,
                        \Build\ file\ '%f'\ line:\ %l,
                        \%+GUnknown\ command-line\ option\ %m,
                        \%+GTask\ %.%#\ not\ found\ %.%#.\ %m,
                        \%E>\ %f:%l:%c:\ %trror:\ %m,
                        \%W>\ %f:%l:%c:\ %tarning:\ %m,
                        \%E%f:%l:\ %trror:\ %m,
                        \%W%f:%l:\ %tarning:\ %m,
                        \%EFAILURE:\ %m,
                        \%Z%p%*[%^~],
                        \%Z>\ %m\ file://%f,
                        \%Z>\ %m,
                        \%C%.%#

