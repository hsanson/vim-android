" if exists("current_compiler")
"   finish
" endif

let current_compiler = 'gradle'

if exists(":CompilerSet") != 2 " for older vims
  command -nargs=* CompilerSet setlocal <args>
endif

exec 'CompilerSet makeprg=' . gradle#bin() . '\ --no-color\ -b\ ' . gradle#findGradleFile()
CompilerSet errorformat=\%+GUnknown\ command-line\ option\ %m,
                        \%-G%f:%l:\ %tarning:\ Element\ SubscribeHandler\ unvalidated\ %.%#,
                        \[ant:checkstyle\]\ %f:%l:%c:\ %m,
                        \[ant:checkstyle\]\ %f:%l:\ %m,
                        \%EExecution\ failed\ for\ task\ '%.%#:findBugs'.,%Z>\ %m.\ See\ the\ report\ at:\ file://%f,
                        \%EExecution\ failed\ for\ task\ '%.%#:lint'.,%Z>\ %m,
                        \Build\ file\ '%f'\ line:\ %l,
                        \>\ There\ were\ failing\ tests.\ See\ the\ report\ at:\ file://%.%#,
                        \%W%f:%l:\ %tarning:\ %m,%Z%p%*[%^~],%+C%.%#,
                        \%E%f:%l:\ %trror:\ %m,%Z%p%*[%^~],%+C%.%#,
                        \%f:\ %tarning:\ %m,
                        \%f:\ %trror:\ %m,
                        \%+GFAILURE:\ %m,
                        \%-G%.%#

