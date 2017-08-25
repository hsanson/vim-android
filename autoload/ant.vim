" Function that tries to determine the location of the ant binary. It will try
" first to find the executalble inside g:ant_path and if not found it will try
" using the ANT_HOME environment variable. If none is found it will search it
" using the vim executable() method.
function! ant#bin()

  if !exists('g:ant_path')
    let g:ant_path = $ANT_HOME
  endif

  let g:ant_bin = g:ant_path . "/bin/ant"

  if(!executable(g:ant_bin))
    if executable("ant")
      let g:ant_bin = "ant"
    else
      echoerr "ant tool could not be found"
      let g:ant_bin = "/bin/false"
    endif
  endif

  return g:ant_bin

endfunction

function! ant#install(device, mode)
  return adb#install(a:device, a:mode)
endfunction

