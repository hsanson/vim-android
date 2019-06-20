function! s:LoadDeps() abort
  return extend(gradle#classPaths(), android#classPaths())
endfunction

function! s:LoadedAle() abort
  if !exists('g:loaded_ale')
    return 0
  endif
  return g:loaded_ale
endfunction

function! ale_linters#java#javalsp#NotifyConfigChange() abort

  if !s:LoadedAle()
    return
  endif

  let l:buffer = bufnr('%')
  let config =
        \ { 
        \  'settings': {
        \    'java': {
        \      'classPath': s:LoadDeps(),
        \      'externalDependencies': []
        \    }
        \  }
        \ }

  call ale#lsp_linter#SendRequest(
        \ l:buffer,
        \ 'javalsp',
        \ [ 0, 'workspace/didChangeConfiguration', l:config ])

  call ale#lsp_linter#SendRequest(
        \ bufnr('%'),
        \ 'javalsp',
        \ ale#lsp#message#DidChange(l:buffer))
endfunction
