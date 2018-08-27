" bucky.vim - Ventilated prose
" Author:   Daniel B. Marques
" Version:  0.1
" License:  Same as Vim

" if exists("g:autoloaded_bucky") || &cp
"   finish
" endif
" let g:autoloaded_bucky = 1

" Format {{{1

function! bucky#md#format() " {{{2
    if mode() =~# '[iR]' | return s:autoformat() | endif
    let lines = getline(v:lnum, v:lnum + v:count - 1) 
    let lines = s:formatBlocks(lines, s:baseIndent(lines))
    call s:setLines(v:lnum, v:count, lines)
endfunction " }}}2

function! s:autoformat() " {{{2
    let line = getline(v:lnum)
    let pline = v:lnum == 0 ? '' : getline(v:lnum - 1)
    let upper = '\(\u\|[ÁÂÃÀÇÉÊÍÓÔÕÜÚ]\)'
    let pattern = '\([.?!]\)\s' . upper
    if line =~ pattern
        let line = substitute(line, pattern, '\1\r\2', '')
        let newLines = split(line, "\r")
        let indent = ''
        if s:startsWithUppercase(line) && s:endsWithPeriod(pline)
            let indent = repeat(' ', s:indent(line))
        else
            let indent = repeat(' ', s:indent(line) - shiftwidth())
        endif
        let newLines[1] = indent . newLines[1]
        call s:setLines(v:lnum, 1, newLines)
        call setline('.', substitute(getline('.'), '\s*$', '', ''))
        execute "normal! j"
        startinsert!
    else
        return -1
    endif
endfunction " }}}2

function! s:formatBlocks(list, baseIndent) " {{{2
    let lines = []
    let formattedLines = []
    let i = 0
    while i < len(a:list)
        let line = a:list[i]
        let pline = i > 0 ? a:list[i-1] : ''
        let prevNonBlank = i > 0 ? s:prevNonBlankNonWhitespace(a:list, i-1) : ''

        if s:isEmptyOrWhitespace(line) || line =~ '^|' || line =~ '^#' " {{{3
            let formattedLines += s:formatLines(lines, a:baseIndent)
            let lines = []
            call add(formattedLines, line)
        " }}}3

        elseif line !~ '[^- ]' " {{{3
            let formattedLines += s:formatLines(lines, a:baseIndent)
            let lines = []
            let z = i + s:findEndOfTable(a:list[i:])
            let formattedLines += a:list[i:z]
            let i = z
        " }}}3

        elseif line =~ '^\s*```' || line =~ '^\s*\~\~\~' " {{{3
            let formattedLines += s:formatLines(lines, a:baseIndent)
            let lines = []
            let z = i + s:findEndOfCode(a:list[i:])
            let formattedLines += a:list[i:z]
            let i = z
        " }}}3

        elseif s:isEmptyOrWhitespace(pline) &&
                    \ s:indent(line) - s:indent(prevNonBlank) >= 4 " {{{3
            let formattedLines += s:formatLines(lines, a:baseIndent)
            let lines = []
            let z = i + s:findEndOfIndent(a:list[i:])
            if z >= i
                let formattedLines += a:list[i:z]
                let i = z
            else
                let formattedLines += a:list[i:-1]
                return formattedLines
            endif
        " }}}3

        else
            call add(lines, line)
        endif
        let i += 1
    endwhile
    let formattedLines += s:formatLines(lines, a:baseIndent)
    return formattedLines
endfunction " }}}2

function! s:formatLines(lines, baseIndent) " {{{2
    let lines = a:lines
    let lines = s:joinText(lines)
    " let lines = s:addIndentation(lines, a:baseIndent)
    let lines = s:breakInSentences(lines)
    if &l:textwidth == 0 | return lines | endif
    let lines = s:breakInLines(lines)
    return lines
endfunction " }}}2

function! s:joinText(lines) " {{{2
    if s:everyItem(a:lines[:-2], 'v:val =~ ''.*,\s*\(%.*\)\?$''')
        return a:lines
    endif

    let joinedLines = []
    let lastLine = ''
    
    for line in a:lines
        let quote = substitute(line, '^\s*\(\(>\s\?\)\+\).*', '\1', '')

        if !s:shouldJoin(line) " {{{3
            if !empty(lastLine)
                call add(joinedLines, lastLine)
                let lastLine = ""
            endif
            call add(joinedLines, line)
        " }}}3

        elseif quote != '' " {{{3
            if lastLine =~ '^' . quote
                let lastLine .= ' ' . substitute(line, '^' . quote, '', '')
            else
                if !empty(lastLine)
                    call add(joinedLines, lastLine)
                    let lastLine = ""
                endif
                let lastLine .= line
            endif
        " }}}3

        elseif line =~ '^\s*\([+*-]\|\d\+\.\)' " {{{3
            if !empty(lastLine)
                call add(joinedLines, lastLine)
                let lastLine = ""
            endif
            let lastLine .= line
        " }}}3

        else " {{{3
            if lastLine =~ '^>'
                call add(joinedLines, lastLine)
                let lastLine = ""
            endif
            if strchars(lastLine) > 0
                    let lastLine .= ' '
            endif
            if s:endsWithPeriod(lastLine)
                call add(joinedLines, lastLine)
                let lastLine = ""
            endif
            let lastLine .= s:stripLeadingWhitespace(line)
        endif " }}}3

    endfor

    if lastLine != ""
        call add(joinedLines, lastLine)
    endif
    return joinedLines
endfunction " }}}2

" function! s:addIndentation(list, baseIndent) " {{{2
"     let lines = []
"     let baseIndent = repeat(' ', a:baseIndent)
"     let i = 0
"     while i < len(a:list)
"         let cline = a:list[i]
"         let cline = s:stripLeadingWhitespace(cline)
"         let pline = i > 0 ? s:prevNonBlankNonWhitespace(lines, i-1) : ''
"         let pInd = repeat(' ', s:indent(pline))
"         if s:isEmptyOrWhitespace(cline)
"             call add(lines, '')
"         elseif cline =~ '^\s*[+*-]\|\d\.' && pline !~ '^\s*[+*-]\|\d\.'
"             call add(lines, '  ' . pInd . cline)
"         else
"             call add(lines, pInd . cline)
"         endif
"         let i += 1
"     endwhile
"     call map(lines, 'baseIndent . v:val')
"     return lines
" endfunction " }}}2

function! s:breakInSentences(list) " {{{2
    let lines = []
    let upper = '\(\u\|[ÁÂÃÀÇÉÊÍÓÔÕÜÚ]\)'
    let pattern = '\(\D[.!?]}\?\)\s\+\(' . upper . '\|\\.\{-}{' . upper . '\)'
    for line in a:list
        if empty(line)
            call add(lines, line)
        else
            let brokenLine = substitute(line, pattern, '\1\r\2', 'g')
            let newLines = split(brokenLine, "\r")
            let firstLine = newLines[0]
            let indentString = repeat(' ', s:indent(firstLine))
            call map(newLines, 'indentString . v:val')
            let newLines[0] = firstLine

            let pattern = '^\s*\(\(>\s\?\)\+\).*'
            if match(line, pattern) >= 0
                let quote = substitute(line, pattern, '\1', '')
                call map(newLines, 'quote . v:val')
                let newLines[0] = firstLine
            endif
            call add(lines, newLines)
        endif
    endfor
    return s:flatten(lines)
endfunction " }}}2

function! s:breakInLines(list) " {{{2
    let brokenText = []
    for line in a:list
        if empty(line)
            call add(brokenText, line)
        else
            call add(brokenText, s:breakLine(line))
        endif
    endfor
    return s:flatten(brokenText)
endfunction " }}}2

function! s:breakLine(string) " {{{2
    let tw = s:textwidth()
    if strchars(a:string) <= tw | return [ a:string ] | endif
    let ind = s:indent(a:string)

    let quote = substitute(a:string, '^\s*\(\(>\s\?\)*\).*', '\1', '')

    let pattern = '\(.\{,'. tw . '}\)\s\(.*\)'
    if match(a:string, pattern, ind) >= 0
        let firstLine = substitute(a:string, pattern, '\1', '')
    else
        return [ a:string ]
    endif
    
    " let width = startsWithComment ? tw - sw - ind - 2 : tw - sw - ind
    let width = tw - strchars(quote) - 2

    let lines = [ firstLine ]
    let remainingLines = substitute(a:string, pattern, '\2', '')
    let pattern = '\(.\{,'. width . '}\)\s\(.*\)'
    while strchars(remainingLines) > width &&
                \ match(remainingLines, pattern) >= 0
        let newLine = quote . '  '
        let newLine .= substitute(remainingLines, pattern, '\1', '')
        let remainingLines = substitute(remainingLines, pattern, '\2', '')
        call add(lines, newLine)
    endwhile
    call add(lines, quote . '  ' . remainingLines)
    return lines
endfunction " }}}2

" }}}1

" Helper functions {{{1

" String manipulation {{{2

function! s:removeDiacritics(string) " {{{3
  let chars        = 'áâãàçéêíóôõüú'
  let replacement  = 'aaaaceeiooouu'
  let chars       .= toupper(chars)
  let replacement .= toupper(replacement)
  return tr(a:string, chars, replacement)
endfunction " }}}3

function! s:stripLeadingWhitespace(string) " {{{3
    return substitute(a:string, '^\s*', '', '')
endfunction " }}}3

" }}}2

" Bool checks {{{2

function! s:shouldJoin(line) " {{{3
    return a:line =~ '\a' &&
         \ a:line =~ '[^=-]' &&
         \ a:line !~ '^\s*#' &&
         \ a:line !~ '^\s*: ' &&
         \ a:line !~ '^| ' &&
         \ a:line !~ '^$$' &&
         \ !s:isEmptyOrWhitespace(a:line)
endfunction " }}}3

function! s:startsWithUppercase(string) " {{{3
    let firstChar = s:firstChar(a:string)
    return s:removeDiacritics(firstChar) =~ '\u'
endfunction " }}}3

function! s:endsWithPeriod(string) " {{{3
    return substitute(a:string, '.\{-}\(.\)$', '\1', '') =~ '[.!?]'
endfunction " }}}3

function! s:isEmptyOrWhitespace(string) " {{{3
    return empty(a:string) || a:string !~ '\S'
endfunction " }}}3

" }}}2

" Getting info {{{2

function! s:textwidth() " {{{3
    let tw = &l:textwidth
    let tw = tw > 0 ? tw : 78
    return tw
endfunction " }}}3

function! s:indent(string) " {{{3
    let spaces = substitute(a:string, '^\(\s*\).*', '\1', '')
    return len(spaces)
endfunction " }}}3

function! s:baseIndent(lines) " {{{3
    let tw = s:textwidth()
    let baseIndent = tw > 0 ? tw : 78
    let openNoIndent = 0
    for line in a:lines
        if !s:isEmptyOrWhitespace(line)
            let lineInd = s:indent(line)
            if lineInd < baseIndent && openNoIndent == 0
                let baseIndent = lineInd
            endif
        endif
        if s:beginsEnv(line) && s:environment(line) =~ g:tex_noindent_env
            let openNoIndent += 1
        endif
        if s:endsEnv(line) && s:environment(line) =~ g:tex_noindent_env
            let openNoIndent -= 1
        endif
    endfor
    return baseIndent == tw ? 0 : baseIndent
endfunction " }}}3

function! s:firstChar(string) " {{{3
    return substitute(a:string, '^\s*\(.\).*', '\1', 'g')
endfunction " }}}3

function! s:prevNonBlankNonWhitespace(list, index) " {{{3
    let i = a:index
    while i > 0
        let line = a:list[i]
        if s:isEmptyOrWhitespace(line)
            let i -= 1
        else
            return line
        endif
    endwhile
    return 0
endfunction " }}}3

function! s:findEndOfQuote(list) " {{{3
    let i = 0
    while i < len(a:list)
        let line = a:list[i]
        if line !~ '^>'
            return i
        endif
        let i += 1
    endwhile
    return len(a:list) - 1
endfunction " }}}3

function! s:findEndOfCode(list) " {{{3
    let pattern = a:list[0] =~ '^\~\~\~' ? '^\~\~\~' : '^```'
    let i = 0
    while i < len(a:list)
        let line = a:list[i]
        if line =~ pattern
            return i
        endif
        let i += 1
    endwhile
    return len(a:list) - 1
endfunction " }}}3

function! s:findEndOfTable(list) " {{{3
    let i = 1
    let passedHeader = 0
    while i < len(a:list)
        let line = a:list[i]
        if s:isEmptyOrWhitespace(line) && !passedHeader
            return i
        elseif line =~ '^[- ]*$' && !passedHeader
            let passedHeader = 1
        elseif !s:isEmptyOrWhitespace(line) && line =~ '^[- ]*$'
            return i
        endif
        let i += 1
    endwhile
    return len(a:list) - 1
endfunction " }}}3

function! s:findEndOfIndent(list) " {{{3
    let indent = s:indent(a:list[0])
    let i = 1
    while i < len(a:list)
        let line = a:list[i]
        if indent - s:indent(line) >= 4
            return i
        endif
        let i += 1
    endwhile
    return len(a:list) - 1
endfunction " }}}3

" }}}2

" Misc {{{2

function! s:setLines(lnum, count, list) " {{{3
    let difference = len(a:list) - a:count
    if difference > 0
        let newLines = repeat([''], difference)
        call append(a:lnum, newLines)
        call setline(a:lnum, a:list)
    elseif difference < 0
        execute a:lnum . ',' . (a:lnum + abs(difference) - 1) . 'd'
        call setline(a:lnum, a:list)
    else
        call setline(a:lnum, a:list)
    endif
endfunction " }}}3

function! s:flatten(list)" {{{3
    let val = []
    for elem in a:list
        if type(elem) == type([])
            call extend(val, s:flatten(elem))
        else
            call add(val, elem)
        endif
        unlet elem
    endfor
    return val
endfunction" }}}3

function! s:addIfNotEmpty(list, item) " {{{3
    if !s:isEmptyOrWhitespace(a:item)
        call add(a:list, a:item)
    endif
endfunction " }}}3

function! s:insertIfNotEmpty(list, item) " {{{3
    if !s:isEmptyOrWhitespace(a:item)
        call insert(a:list, a:item)
    endif
endfunction " }}}3

function! s:everyItem(list, condition) " {{{3
    let list = deepcopy(a:list)
    let result = map(list, a:condition)
    return index(result, 0) < 0
endfunction " }}}3

" }}}2

" }}}1

