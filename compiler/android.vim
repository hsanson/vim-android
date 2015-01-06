" if exists("current_compiler")
"   finish
" endif

let current_compiler = 'android'

if exists(":CompilerSet") != 2 " for older vims
  command -nargs=* CompilerSet setlocal <args>
endif

if android#isGradleProject()
  exec 'CompilerSet makeprg=' . gradle#bin() . '\ --no-color\ -i\ -b\ ' . android#findGradleFile()
  CompilerSet errorformat=\[ant:checkstyle\]\ %f:%l:%c:\ %m,
                          \[ant:checkstyle\]\ %f:%l:\ %m,
                          \%EExecution\ failed\ for\ task\ '%.%#:findBugs'.,%Z>\ %m.\ See\ the\ report\ at:\ file://%f,
                          \%EExecution\ failed\ for\ task\ '%.%#:lint'.,%Z>\ %m,
                          \>\ There\ were\ failing\ tests.\ See\ the\ report\ at:\ file://%.%#,
                          \%A%f:%l:\ %tarning:\ %m,%-Z%p^,%-C%.%#,
                          \%A%f:%l:\ %trror:\ %m,%-Z%p^,%-C%.%#
elseif android#isAntProject()
  exec 'CompilerSet makeprg=' . ant#bin() . '\ -f\ ' . android#findAntFile()
  CompilerSet errorformat=\ %#[javac]\ %#%f:%l:%c:%*\\d:%*\\d:\ %t%[%^:]%#:%m,
                \%A\ %#[javac]\ %f:%l:\ %m,
                \Error:\ %m,
                \%A\ %#[aapt]\ %f:%l:\ %m,%-Z\ %#[javac]\ %p^,%-C%.%#,
                \%A\ %#[exec]\ Failure\ [%m]
endif
