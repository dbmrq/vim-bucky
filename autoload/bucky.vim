" bucky.vim - Ventilated prose
" Author:   Daniel B. Marques
" Version:  0.1
" License:  Same as Vim

" if exists("g:autoloaded_bucky") || &cp
"   finish
" endif
" let g:autoloaded_bucky = 1

function! bucky#indent() " {{{1
    let cnum = v:lnum
    let lnum = bucky#prevNonBlankNonComment(cnum - 1)
    let pnum = bucky#prevNonComment(lnum - 1)
    if lnum == 0 | return 0 | endif
    let cline = getline(cnum)
    let lline = getline(lnum)
    let pline = getline(pnum)
    let ind = indent(lnum)

    if bucky#endsWithPeriod(lline) &&
        \ (bucky#isEmptyOrWhitespace(cline) || bucky#startsWithUppercase(cline))
            return ind - shiftwidth()
    elseif bucky#startsWithUppercase(lline) &&
        \ (empty(pline) || bucky#endsWithPeriod(pline))
            return ind + shiftwidth()
    else
        return ind
    endif
endfunction " }}}1

