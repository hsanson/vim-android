function! aapt#bin()

  if exists('g:android_aapt_tool')
    return g:android_aapt_tool
  endif

  let l:aapt_paths = [
        \ android#buildToolsPath() . '/aapt',
        \ 'aapt',
        \ android#buildToolsPath() . '/aapt2',
        \ 'aapt2',
        \ '/bin/false'
        \ ]

  for l:path in l:aapt_paths
    if(executable(l:path))
      let g:android_aapt_tool = l:path
      break
    endif
  endfor

  return g:android_aapt_tool
endfunction
