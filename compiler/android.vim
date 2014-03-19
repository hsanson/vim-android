if exists("current_compiler")
  finish
endif

let current_compiler = 'android'

if exists(":CompilerSet") != 2 " for older vims
  command -nargs=* CompilerSet setlocal <args>
endif

if android#isGradleProject()
  exec 'CompilerSet makeprg=' . gradle#bin() . '\ --no-color'
  CompilerSet errorformat=%f:%l:\ %m,
      \%A%f:%l:\ %m,%-Z%p^,%-C%.%#
elseif android#isAntProject()
  exec 'CompilerSet makeprg=' . ant#bin() . '\ -find\ build.xml'
  CompilerSet errorformat=\ %#[javac]\ %#%f:%l:%c:%*\\d:%*\\d:\ %t%[%^:]%#:%m,
                \%A\ %#[javac]\ %f:%l:\ %m,
                \Error:\ %m,
                \%A\ %#[aapt]\ %f:%l:\ %m,%-Z\ %#[javac]\ %p^,%-C%.%#,
                \%A\ %#[exec]\ Failure\ [%m]
endif
