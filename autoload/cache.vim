
let s:cache = {}

" Returns 1 if the key exists on the given store or 0 otherwise.
function! cache#has(store, key) abort
endfunction

" Returns the value stored in the key/store
function! cache#get(store, key, ...) abort
  let l:store = s:getStore(a:store)
  let l:default = get(a:, 1, '')

  if !has_key(l:store, a:key)
    let l:store[a:key] = l:default
  end
  return l:store[a:key]
endfunction

function! cache#set(store, key, value) abort
  let l:store = s:getStore(a:store)
  let l:store[a:key] = a:value
  return a:value
endfunction

" Generates a unique key from a file on disk.
function! cache#key(filepath) abort
  if !filereadable(a:filepath)
    return 'nogradle'
  end
  return a:filepath . getftime(a:filepath)
endfunction

function! s:getStore(store) abort
  if !has_key(s:cache, a:store)
    let s:cache[a:store] = {}
  end
  return s:cache[a:store]
endfunction
