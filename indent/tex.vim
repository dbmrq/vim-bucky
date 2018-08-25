" bucky.vim - Ventilated prose
" Author:   Daniel B. Marques
" Version:  0.1
" License:  Same as Vim

" if exists("g:loaded_bucky") || &cp
"   finish
" endif
" let g:loaded_bucky = 1

setlocal indentexpr=BuckyTeXIndent()

function! BuckyTeXIndent() " {{{1
    let cnum = v:lnum
    " let lnum = cnum - 1
    let lnum = s:prevNonBlankNonComment(cnum - 1)
    let pnum = s:prevNonComment(lnum - 1)
    let cline = getline(cnum)
    let lline = getline(lnum)
    let pline = getline(pnum)

    if cline =~ '^\s*%' | return indent(cnum) | endif

    let ind = indent(lnum)

    if exists("*VimtexIndentExpr")
        let ind = VimtexIndentExpr()
    elseif exists("*GetTexIndent")
        let ind = GetTeXIndent()
    endif

    if s:isVerbatim(cnum)
        return ind
    elseif cline =~ '^\s*\\\(begin\|end\){.\{-}}'
        return 0
    elseif lline =~ '^\s*\\item' && cline !~ '^\s*\\item'
        echom cline
        let ind = indent(lnum)
        if s:shouldEndSentenceIndent(cline, lline, pline)
            return ind - shiftwidth() + 6
        elseif s:shouldAddSentenceIndent(cline, lline, pline)
            return ind + shiftwidth() + 6
        else
            return ind + 6
        endif
    elseif cline =~ '^\s*\\item' && lline !~ '^\s*\\item' &&
                \ lline !~ '^\s*\\\(begin\|end\){.\{-}}'
        return ind - 6
    elseif s:shouldEndSentenceIndent(cline, lline, pline)
        return ind - shiftwidth()
    elseif cnum - lnum == 1 && s:shouldAddSentenceIndent(cline, lline, pline)
        return ind + shiftwidth()
    " elseif cline =~ '^\s*\\end{.\{-}}'
    "     return ind - shiftwidth() * 2
    " elseif cline =~ '^\s*\\begin{.\{-}}' && lline =~ '^\s*\l'
    "     return ind - shiftwidth() * 2
    elseif lline =~ '^\s*\\begin{.\{-}}'
        return ind + shiftwidth()
    endif
    return ind
endfunction " }}}1

" Helper functions {{{1

function! s:isVerbatim(line) " {{{2
    return synIDattr(synID(a:line, indent(a:line), 1), "name") == "texZone"
endfunction " }}}2

function! s:shouldAddSentenceIndent(cline, lline, pline) " {{{2
    if s:isSingleCommand(a:lline)
    " if cline =~ '^\s*\\begin{.\{-}}'
        return 0
    endif
    return (s:startsWithUppercase(a:lline) || a:lline =~ '^\s*\\item') &&
        \ !s:endsWithPeriod(a:lline) &&
        \ !s:isSingleCommand(a:cline) &&
        \ a:lline !~ '^\s*%' &&
        \ a:lline !~ '[.?!]$' &&
        \ a:pline !~ '\a$' &&
        \ a:cline !~ '^\s*\\item'
endfunction " }}}2

function! s:shouldEndSentenceIndent(cline, lline, pline) " {{{2
    " echom s:endsWithPeriod(a:lline) &&
    "     \ (!s:startsWithUppercase(a:lline) || a:pline =~ '\a$')
    return s:endsWithPeriod(a:lline) &&
        \ (!s:startsWithUppercase(a:lline) || a:pline =~ '\a$') &&
            \ (s:isEmptyOrWhitespace(a:cline) ||
             \ s:startsWithUppercase(a:cline) ||
             \ s:isSingleCommand(a:cline) ||
             \ a:cline !~ '\w' ||
             \ a:cline =~ '^\s*%'
             \ )
endfunction " }}}2

function! s:prevNonComment(line) " {{{2
    let lnum = a:line
    while lnum != 0 && s:startsWithComment(getline(lnum))
        let lnum = lnum - 1
    endwhile
    return lnum
endfunction " }}}2

function! s:prevNonBlankNonComment(line) " {{{2
    let lnum = prevnonblank(a:line)
    while lnum != 0 && s:startsWithComment(getline(lnum))
        let lnum = prevnonblank(lnum - 1)
    endwhile
    return lnum
endfunction " }}}2


function! s:startsWithUppercase(string) " {{{2
    let string = s:removeDiacritics(a:string)
    return string =~ '^\s*\(\\\a\{-}{\)\?\u' || string =~ '^\s*\\textcite'
endfunction " }}}2

function! s:endsWithPeriod(string) " {{{2
    return a:string =~ '[.!?]\s*$'
endfunction " }}}2

function! s:isEmptyOrWhitespace(string) " {{{2
    return empty(a:string) || a:string !~ '\S'
endfunction " }}}2

function! s:isSingleCommand(string) " {{{2
    if !s:bracesAreMatched(a:string)
        return 0
    endif
    let pattern = '^\s*\\\(.\|[A-Za-z@]\{-}\)\(\[.\{-}\]\)\?'
    let pattern .= '\({.\{-}}\)*\s*\(%.*\)\?$'
    return a:string =~ pattern
endfunction " }}}2

function! s:startsWithComment(string) " {{{2
    return a:string =~ '^\s*%'
endfunction " }}}2

function! s:removeDiacritics(string) " {{{2
  let chars        = 'áâãàçéêíóôõüú'
  let replacement  = 'aaaaceeiooouu'
  let chars       .= toupper(chars)
  let replacement .= toupper(replacement)
  return tr(a:string, chars, replacement)
endfunction " }}}2

function! s:bracesAreMatched(string) " {{{2
    let string = s:removeMatchedBraces(a:string)
    return string !~ '[[\]{}]'
endfunction " }}}2

function! s:removeMatchedBraces(string) " {{{2
    let string = a:string
    let pattern = '{[^{}]\{-}}'
    while match(string, pattern) >= 0
        let string = substitute(string, pattern, '', 'g')
    endwhile
        let string = substitute(string, pattern, '', 'g')
    endwhile
    return string
endfunction " }}}2

" }}}1

