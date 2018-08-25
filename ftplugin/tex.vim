" bucky.vim - Ventilated prose
" Author:   Daniel B. Marques
" Version:  0.1
" License:  Same as Vim

" if exists("g:loaded_bucky") || &cp
"   finish
" endif
" let g:loaded_bucky = 1

if !exists("g:tex_noindent_env")
    let g:tex_noindent_env = 'document\|verbatim\|lstlisting'
endif

setlocal formatexpr=bucky#tex#format()

