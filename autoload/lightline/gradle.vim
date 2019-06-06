function! s:BuildingLine() abort
  return gradle#glyphBuilding() . ' ' . gradle#jobCount()
endfunction

function! lightline#gradle#running() abort
  return gradle#running() ? s:BuildingLine() : ''
endfunction

function! lightline#gradle#project() abort
  return gradle#glyphProject()
endfunction

function! lightline#gradle#warnings() abort
  let l:count = gradle#getWarningCount()
  if l:count == 0
    return ''
  end
  return g:gradle#glyphWarning() . ' ' . l:count
endfunction

function! lightline#gradle#errors() abort
  let l:count = gradle#getErrorCount()
  if l:count == 0
    return ''
  end
  return g:gradle#glyphError() . ' ' . l:count
endfunction

