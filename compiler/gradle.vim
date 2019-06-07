let current_compiler = 'gradle'

if exists(':CompilerSet') != 2 " for older vims
  command -nargs=* CompilerSet setlocal <args>
endif

exec 'CompilerSet makeprg=' . efm#makeprg()
exec 'CompilerSet errorformat=' . efm#escape(efm#efm())
