let current_compiler = 'gradle'

if exists(":CompilerSet") != 2 " for older vims
  command -nargs=* CompilerSet setlocal <args>
endif

exec 'CompilerSet makeprg=' . efm#buildMakeprg()
exec 'CompilerSet errorformat=' . efm#escapeEfm(efm#buildEfm())
