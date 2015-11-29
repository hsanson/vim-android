
function! GradleAirlineInit()

  if !exists('g:gradle_airline_android_glyph')
    let g:gradle_airline_android_glyph = ''
  endif

  let g:airline_initialized = 1
  let w:airline_section_warning = '%{gradle#airlineErrorStatus()}'

  let w:airline_section_b = '%{gradle#airlineStatus()}'

  call airline#parts#define_raw('vim-android', g:gradle_airline_android_glyph)
  call airline#parts#define_condition('vim-android', 'android#isAndroidProject()')
  call airline#parts#define_function('vim-gradle-status', 'gradle#airlineStatus')
  call airline#parts#define_function('vim-gradle-error', 'gradle#airlineErrorStatus')

  let g:airline_section_a = airline#section#create(['mode', ' ', 'vim-android'])
  let g:airline_section_x= airline#section#create(['vim-gradle-status'])
  let g:airline_section_warning= airline#section#create(['vim-gradle-error', 'syntastic', 'whitespace'])

endfunction

autocmd User AirlineAfterInit call GradleAirlineInit()

