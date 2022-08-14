function! s:LoadDeps() abort
  return gradle#uniq(sort(gradle#classPaths()))
endfunction

function! s:LoadedAle(buffer, linter) abort
  if !exists('g:loaded_ale')
    return 0
  endif

  if !exists('g:ale_linters')
    return 0
  endif

  let l:ft = getbufvar(a:buffer, '&filetype')

  if !has_key(g:ale_linters, l:ft)
    return 0
  endif

  if index(g:ale_linters[l:ft], a:linter) < 0
    return 0
  endif

  return g:loaded_ale
endfunction

function! ale_linters#java#EclipseLspNotifyConfigChange() abort

  let l:buffer = bufnr('%')

  if s:LoadedAle(l:buffer, 'eclipselsp')
    let config =
          \ {
          \  'settings': {
          \    'java': {
          \      'project': {
          \        'referencedLibraries': s:LoadDeps()
          \      }
          \    }
          \  }
          \ }

    call ale#lsp_linter#SendRequest(
          \ l:buffer,
          \ 'eclipselsp',
          \ [ 0, 'workspace/didChangeConfiguration', l:config ])

    call ale#lsp_linter#SendRequest(
          \ bufnr('%'),
          \ 'eclipselsp',
          \ ale#lsp#message#DidChange(l:buffer))
  endif

endfunction

function! ale_linters#java#JavaLspNotifyConfigChange() abort

  let l:buffer = bufnr('%')

  if s:LoadedAle(l:buffer, 'javalsp')
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
  endif

endfunction

function! ale_linters#java#NotifyConfigChange() abort
  call ale_linters#java#JavaLspNotifyConfigChange()
  call ale_linters#java#EclipseLspNotifyConfigChange()
endfunction
