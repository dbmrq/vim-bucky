" bucky.vim - Ventilated prose
" Author:   Daniel B. Marques
" Version:  0.1
" License:  Same as Vim

" if exists("g:loaded_bucky") || &cp
"   finish
" endif
" let g:loaded_bucky = 1

setlocal formatexpr=bucky#md#format()

