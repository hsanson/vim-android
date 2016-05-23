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

if gradle#isDaemonEnabled()
  call add(s:makeprg, "--daemon")
endif

exec 'CompilerSet makeprg=' . join(s:makeprg, '\ ')

CompilerSet errorformat=
    \%+ATask\ %.%#\ not\ found\ %.%#.,
    \%EExecution\ failed\ for\ task\ %m,
    \findbugs:\ %tarning\ %f:%l:%c\ %m,
    \pmd:\ %tarning\ %f:%l:%c\ %m,
    \checkstyle:\ %tarning\ %f:%l:%c\ %m,
    \lint:\ %tarning\ %f:%l:%c\ %m,
    \%A>\ %f:%l:%c:\ %trror:\ %m,
    \%A>\ %f:%l:%c:\ %tarning:\ %m,
    \%A%f:%l:\ %trror:\ %m,
    \%A%f:%l:\ %tarning:\ %m,
    \%A%f:%l:\ %trror\ -\ %m,
    \%A%f:%l:\ %tarning\ -\ %m,
    \%E%f:%l\ :\ %m,
    \%C>\ %m,
    \%-G%p^,
    \%+G\ \ %.%#,
    \%-G%.%#

