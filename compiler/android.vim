" Vim compiler file for Android projects
"
" Author: Horacio Sanson
" 
" Resources:
"   http://blog.vinceliu.com/2007/08/vim-tips-for-java-1-build-java-files.html

if exists("current_compiler")
  finish
endif

let current_compiler = 'android'

" Command to generate java tags
"  ctags --recurse --langmap=Java:.java --languages=Java --verbose -f ~/.vim/tags/android ANDROID_SDK/sources
set tags+=~/.vim/tags/android

CompilerSet makeprg=ant\ -find\ build.xml
CompilerSet efm=\ %#[javac]\ %#%f:%l:%c:%*\\d:%*\\d:\ %t%[%^:]%#:%m,
                \%A\ %#[javac]\ %f:%l:\ %m,
                \%A\ %#[aapt]\ %f:%l:\ %m,%-Z\ %#[javac]\ %p^,%-C%.%#
