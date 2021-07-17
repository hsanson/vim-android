function! aapt#bin()

  if exists('g:android_aapt_tool')
    return g:android_aapt_tool
  endif

  let g:android_aapt_tool = android#buildToolsPath() . '/aapt2'

  if(executable(g:android_aapt_tool))
    return g:android_aapt_tool
  endif

  let g:android_aapt_tool='aapt2'

  if(executable(g:android_aapt_tool))
    return g:android_aapt_tool
  endif

  let g:android_aapt_tool='/bin/false'

  return g:android_aapt_tool
endfunction
