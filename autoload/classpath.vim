let s:entry = "\t<classpathentry kind=\"<kind>\" path=\"<path>\"/>"
let s:entry_sourcepath = "\t<classpathentry kind=\"<kind>\" path=\"<path>\" sourcepath=\"<src>\"/>"

function! classpath#generateClasspathFile() abort

  if !exists('g:gradle_gen_classpath_file')
    let g:gradle_gen_classpath_file = 1
  endif

  if g:gradle_gen_classpath_file != 1
    return
  endif

  call s:generateClasspathFile()
endfunction

" Creates a .classpath file and fills it with dependency entries
function! s:generateClasspathFile() abort

  " For non android project JDT generated .classpath file works fine. No need to
  " fiddle with it. For android project in the other hand the JDT generated one
  " does not work so we generate one that works with android dependencies.
  if !android#isAndroidProject()
    return
  endif

  let l:contents = []
  let l:path = classpath#findClasspathFile()

  if len(l:path) == 0
    let l:path = gradle#findRoot() . '/.classpath'
  endif

  let l:contents = ['<?xml version="1.0" encoding="UTF-8"?>', '<classpath>', '</classpath>']

  " Note that order is important. Sources must be added before libs in the
  " .classpath file.
  "
  let l:srcs = extend(gradle#sourcePaths(), android#sourcePaths())

  for src in l:srcs
      let l:relativeSrc =  fnamemodify(src, ':s?' . gradle#findRoot() . '/??')
      let l:row = s:newClassEntry('src', relativeSrc)
      if index(l:contents, l:row) < 0
        call insert(l:contents, l:row, -1)
      endif
  endfor

  let l:classes = gradle#classPaths()

  for jar in l:classes
    let l:row = s:newClassEntry('lib', jar)
    if index(l:contents, l:row) < 0
      call insert(l:contents, l:row, -1)
    endif
  endfor

  let l:row =  s:newClassEntry('lib', '.')

  if index(l:contents, l:row) < 0
    call insert(l:contents, l:row, -1)
  endif

  call writefile(l:contents, l:path)
endfunction

" Generates .classpath file required by some tools to figure out dependencies
" (e.g. Eclipse JDT).

" Adds a new entry to the current .classpath file.
function! s:newClassEntry(kind, arg, ...)
  let template_name = 's:entry'
  let args = {'kind': a:kind, 'path': substitute(a:arg, '\', '/', 'g')}

  if a:0 == 1
      let template_name = 's:entry_sourcepath'
      let args['src'] = substitute(a:1, '\', '/', 'g')
  endif

  if exists(template_name . '_' . a:kind)
    let template = {template_name}_{a:kind}
  else
    let template = {template_name}
  endif

  for [key, value] in items(args)
    let template = substitute(template, '<' . key . '>', value, 'g')
  endfor

  return template
endfunction

function! classpath#findClasspathFile()
  let l:file = findfile('.classpath', gradle#findRoot() . ';$HOME')

  if len(l:file) == 0
    return ''
  endif

  return copy(fnamemodify(l:file, ':p'))
endfunction
