
function ale_linters#android#Define(language) abort

	if !exists('g:loaded_ale')
    return
  endif

  call ale#linter#Define(a:language, {
  \   'name': 'android',
  \   'executable': function('ale_linters#android#Executable'),
  \   'command': function('ale_linters#android#Command'),
  \   'callback': 'ale_linters#android#Handler',
  \})
endfunction

function ale_linters#android#Executable(buffer) abort
  if android#isAndroidProject()
    return gradle#bin()
  endif
  return ''
endfunction

function ale_linters#android#Handler(buffer, lines) abort
  let l:pattern = 'lint: Warning \(.\+\):\(\d\+\):\(\d\+\) \(.\+\)$'
  let l:output = []

  for l:match in ale#util#GetMatches(a:lines, l:pattern)
      call add(l:output, {
      \   'filename': l:match[1],
      \   'type': 'W',
      \   'lnum': l:match[2] + 0,
      \   'col': l:match[3] + 0,
      \   'text': l:match[4],
      \})
  endfor

  return l:output
endfunction

function ale_linters#android#Command(buffer) abort
  return join(gradle#cmd('lint'), ' ') . ' %t'
endfunction
