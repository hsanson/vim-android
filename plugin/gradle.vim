
function! GradleAirlineInit()
  let g:airline_initialized = 1
  call airline#parts#define_function('vim-gradle-status', 'gradle#airlineStatus')
  call airline#parts#define_function('vim-gradle-error', 'gradle#airlineErrorStatus')
  let g:airline_section_x= airline#section#create_right(['tagbar', 'filetype', 'vim-gradle-status'])
  let g:airline_section_warning= airline#section#create(['vim-gradle-error', 'syntastic', 'whitespace'])
endfunction

autocmd User AirlineAfterInit call GradleAirlineInit()

