let s:entry = "\t<classpathentry kind=\"<kind>\" path=\"<path>\"/>"
let s:entry_sourcepath = "\t<classpathentry kind=\"<kind>\" path=\"<path>\" sourcepath=\"<src>\"/>"

" Creates a .classpath file and fills it with dependency entries
function! classpath#generateClasspath() abort
  let l:classes = gradle#classPaths()
  let l:srcs = extend(gradle#sourcePaths(), android#sourcePaths())

  let classpath = ['<?xml version="1.0" encoding="UTF-8"?>', '<classpath>']
  for src in l:srcs
      let l:relativeSrc =  fnamemodify(src, ":s?" . gradle#findRoot() . "/??")
      call add(classpath, s:newClassEntry('src', relativeSrc))
  endfor
  for jar in l:classes
    call add(classpath, s:newClassEntry('lib', jar))
  endfor
  call add(classpath, s:newClassEntry('lib', '.'))
  call add(classpath, '</classpath>')

  call writefile(classpath, gradle#findRoot() . '/.classpath')
endfunction

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
