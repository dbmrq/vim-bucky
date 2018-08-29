" bucky.vim - Ventilated prose
" Author:   Daniel B. Marques
" Version:  0.1
" License:  Same as Vim

" if exists("g:autoloaded_bucky") || &cp
"   finish
" endif
" let g:autoloaded_bucky = 1

" Format {{{1

function! bucky#tex#format() " {{{2
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

        if s:isEmptyOrWhitespace(line) " {{{3
            let formattedLines += s:formatLines(lines, a:baseIndent)
            let lines = []
            call add(formattedLines, line)
        " }}}3

        elseif s:startsWithComment(line) " {{{3
            let formattedLines += s:formatLines(lines, a:baseIndent)
            let lines = []
            let z = i + s:findEndOfComment(a:list[i:])
            let comment = a:list[i:z]
            if s:shouldFormatComments()
                call map(comment, 'substitute(v:val, ''^\s*%'', '''', '''')')
                let formattedComment = s:formatBlocks(comment, a:baseIndent + 2)
                call map(formattedComment, 'substitute(v:val, ''^\s\{' .
                            \ a:baseIndent . '}\zs\s\s'', ''% '', '''')')
                let formattedLines += formattedComment
            else
                let formattedLines += s:formatComment(comment, a:baseIndent)
            endif
            let i = z
        " }}}3

        elseif s:beginsEnv(line) " {{{3
            " Format previous lines
            let brokenBegin = s:breakAroundBegin(line)
            let beforeBegin = brokenBegin[0]
            let begin = brokenBegin[1]
            let afterBegin = brokenBegin[2]
            let envIndent =
                \ s:environment(begin) =~ s:sentenceEnvironments() ?
                \ a:baseIndent + shiftwidth() : a:baseIndent
            call s:addIfNotEmpty(lines, beforeBegin)
            let formattedLines += s:formatLines(lines, a:baseIndent)
            let formattedLines += s:formatLines([begin], envIndent)
            let lines = []
            " Format group
            let z = i + s:findEnd(a:list[i:])
            if z >= i
                let brokenEnd = z == i ? s:breakAroundEnd(afterBegin) : s:breakAroundEnd(a:list[z])
                let afterBegin = z == i ? '' : afterBegin
                let beforeEnd = brokenEnd[0]
                let end = brokenEnd[1]
                let afterEnd = brokenEnd[2]
                if s:environment(begin) =~ g:tex_noindent_env
                    call s:addIfNotEmpty(formattedLines, afterBegin)
                    let formattedLines += a:list[i+1:z-1]
                    call s:addIfNotEmpty(formattedLines, beforeEnd)
                else
                    let body = z == i ? [] : a:list[i+1:z-1]
                    call s:insertIfNotEmpty(body, afterBegin)
                    call s:addIfNotEmpty(body, beforeEnd)
                    let formattedLines += s:formatBlocks(body,
                                \ envIndent + shiftwidth())
                endif
                if afterEnd !~ '\a'
                    let formattedLines += s:formatLines([end . afterEnd], envIndent)
                    " call s:addIfNotEmpty(lines, end . afterEnd)
                else
                    let formattedLines += s:formatLines([end], envIndent)
                    " call s:addIfNotEmpty(lines, end)
                    call s:addIfNotEmpty(lines, afterEnd)
                endif
                let i = z
            else
                let body = a:list[i+1:-1]
                call s:insertIfNotEmpty(body, afterBegin)
                let formattedLines += s:formatBlocks(body, a:baseIndent+shiftwidth())
                return formattedLines
            endif
        " }}}3

        elseif s:opensBrace(line) " {{{3
            call add(lines, a:list[i])
            let formattedLines += s:formatLines(lines, a:baseIndent)
            let lines = []
            let z = i + s:findMatchingBrace(a:list[i:])
            if z >= i
                let body = a:list[i+1:z-1]
                let formattedLines += s:formatBlocks(body, a:baseIndent+shiftwidth())
                call add(lines, a:list[z])
                let i = z
            else
                let body = a:list[i+1:-1]
                let formattedLines += s:formatBlocks(body, a:baseIndent+shiftwidth())
                return formattedLines
            endif
        " }}}3

        else
            call add(lines, line)
        endif
        let i += 1
    endwhile
    " Format remaining lines
    let formattedLines += s:formatLines(lines, a:baseIndent)
    let i = 0
    while i < len(formattedLines)
        if formattedLines[i] =~ '\\end{.\{-}}' && formattedLines[i+1] =~ '^\s*\U'
            let formattedLines[i+1] = repeat(' ', s:indent(formattedLines[i])) .
                        \ formattedLines[i+1]
        endif
        let i += 1
    endwhile
    return formattedLines
endfunction " }}}2

function! s:formatLines(lines, baseIndent) " {{{2
    let lines = a:lines
    let lines = s:joinText(lines)
    let lines = s:addIndentation(lines, a:baseIndent)
    let lines = s:breakInSentences(lines)
    if &l:textwidth == 0 | return lines | endif
    let lines = s:indentAfterComment(lines)
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

        if !s:shouldJoin(line) " {{{3
            if !empty(lastLine)
                call add(joinedLines, lastLine)
                let lastLine = ""
            endif
            call add(joinedLines, line)
        " }}}3

        elseif s:startsWithItem(line) " {{{3
            if !empty(lastLine)
                call add(joinedLines, lastLine)
                let lastLine = ""
            endif
            let lastLine .= line
        " }}}3

        elseif s:startsWithComment(line) " {{{3
            if s:startsWithComment(lastLine)
                if strchars(lastLine) > 0 && !s:startsWithSlash(line)
                    let lastLine .= ' '
                endif
                let lastLine .= substitute(line, '^\s*%\s*\(.*\)', '\1', '')
            else
                if !empty(lastLine)
                    call add(joinedLines, lastLine)
                    let lastLine = ""
                endif
                let lastLine .= s:stripLeadingWhitespace(line)
            endif
        " }}}3

        else " {{{3
            " if s:startsWithComment(lastLine)
            if lastLine =~ '%'
                call add(joinedLines, lastLine)
                let lastLine = ""
            endif
            " if strchars(lastLine) > 0 && !s:startsWithSlash(line)
            if strchars(lastLine) > 0 &&
                \ !s:startsWithCommand(line, 'footcite') &&
                \ !s:startsWithCommand(line, 'footnote')
                    let lastLine .= ' '
            endif
            if s:startsWithCommand(line, 'textcite') && s:endsWithPeriod(lastLine)
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

function! s:addIndentation(list, baseIndent) " {{{2
    let lines = []
    let baseIndent = repeat(' ', a:baseIndent)
    let i = 0
    while i < len(a:list)
        let cline = a:list[i]
        let cline = s:stripLeadingWhitespace(cline)
        let pline = i > 0 ? s:prevNonBlankNonWhitespace(lines, i-1) : ''
        let pInd = repeat(' ', s:indent(pline))
        if s:isEmptyOrWhitespace(cline)
            call add(lines, '')
        else
            call add(lines, pInd . cline)
        endif
        let i += 1
    endwhile
    call map(lines, 'baseIndent . v:val')
    return lines
endfunction " }}}2

function! s:breakInSentences(list) " {{{2
    let lines = []
    let pattern = '\([.!?]}\?\)\s\+\(' . s:upperOrCommand() . '\|\$\)'
    for line in a:list
        if empty(line)
            call add(lines, line)
        elseif !s:startsWithComment(line) || s:shouldFormatComments() 
            let brokenLine = substitute(line, pattern, '\1\r\2', 'g')
            let newLines = split(brokenLine, "\r")
            let firstLine = newLines[0]
            let indentString = firstLine =~ '\\end{.\{-}}' ?
                        \ repeat(' ', s:indent(firstLine) - shiftwidth()) :
                        \ repeat(' ', s:indent(firstLine))
            " if firstLine =~ '^\s*\l'
            "     let firstLine = repeat(' ', shiftwidth()) . firstLine
            "     let indentString = repeat(' ',
            "                 \ s:indent(firstLine) - shiftwidth())
            " endif
            let indentString = s:startsWithItem(firstLine) ?
                \ repeat(' ', 6) . indentString : indentString
            let commentString = s:startsWithComment(line) ? '% ' : ''
            call map(newLines, 'indentString . commentString . v:val')
            let newLines[0] = firstLine
            call add(lines, newLines)
        else 
            call add(lines, line)
        endif
    endfor
    return s:flatten(lines)
endfunction " }}}2

function! s:indentAfterComment(list) " {{{2
    let lines = []
    let i = 0
    while i < len(a:list)
        let line = a:list[i]
        let pline = i > 0 ? a:list[i-1] : ''
        if pline =~ "%.*" && pline !~ "%\.$" &&
            \ (pline !~ "[.!?]\s*%" || line !~ "^\s*" . s:upperOrCommand())
                let ind = s:indent(pline) + shiftwidth()
                call add(lines, repeat(' ', ind) . line)
        else
            call add(lines, line)
        endif
        let i += 1
    endfor
    return lines
endfunction " }}}2

function! s:formatComment(lines, baseIndent) " {{{2
    let lines = a:lines
    let lines = s:joinText(lines)
    let lines = s:addIndentation(lines, a:baseIndent)
    let lines = s:breakInLines(lines)
    return lines
endfunction " }}}2

function! s:breakInLines(list) " {{{2
    let brokenText = []
    let i = 0
    while i < len(a:list)
        let line = a:list[i]
        let pline = i > 0 ? a:list[i-1] : ''
        if empty(line)
            call add(brokenText, line)
        elseif pline =~ "%.*" && pline !~ "%\.$" &&
            \ (pline !~ "[.!?]\s*%" || line !~ "^\s*" . s:upperOrCommand())
        " elseif pline =~ "[^.!?]\s*%.*" && pline !~ "%\.$"
                call add(brokenText, s:breakLine(line, 0))
        else
            call add(brokenText, s:breakLine(line))
        endif
        let i += 1
    endwhile
    return s:flatten(brokenText)
endfunction " }}}2

function! s:breakLine(string, ...) " {{{2
    let tw = s:textwidth()
    if strchars(a:string) <= tw | return [ a:string ] | endif
    let startsWithComment = s:startsWithComment(a:string)
    let ind = strchars(substitute(a:string,
                \ '\(\s*\(\\item\s\)\?\).*', '\1', ''))
    let sw = a:0 ? a:1 : shiftwidth()
    if startsWithComment && s:shouldFormatComments()
        let comment = repeat(' ', ind) . '% '
        let spaces = repeat(' ', sw)
    elseif startsWithComment
        let comment = repeat(' ', ind) . '% '
        let cInd = s:indent(substitute(a:string, '^\s*%', '', '')) - 1
        let spaces = repeat(' ', cInd)
    elseif !s:startsWithUppercase(a:string) && a:string !~ '^\s*\$'
        let comment = ''
        let spaces = repeat(' ', ind)
    else
        let comment = ''
        let spaces = repeat(' ', sw + ind)
    endif

    let pattern = '\(.\{,'. tw . '}\)\s\(.*\)'
    if match(a:string, pattern, ind) >= 0
        let firstLine = substitute(a:string, pattern, '\1', '')
    else
        return [ a:string ]
    endif
    
    " let width = startsWithComment ? tw - sw - ind - 2 : tw - sw - ind
    let width = tw - strchars(comment) - strchars(spaces)

    let lines = [ firstLine ]
    let remainingLines = substitute(a:string, pattern, '\2', '')
    let pattern = '\(.\{,'. width . '}\)\s\(.*\)'
    while strchars(remainingLines) > width &&
                \ match(remainingLines, pattern) >= 0
        let newLine = comment . spaces
        let newLine .= substitute(remainingLines, pattern, '\1', '')
        let remainingLines = substitute(remainingLines, pattern, '\2', '')
        call add(lines, newLine)
    endwhile
    call add(lines, comment . spaces . remainingLines)
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

function! s:removeMatchedBraces(string) " {{{3
    let string = a:string
    let pattern = '{[^{}]\{-}}'
    while match(string, pattern) >= 0
        let string = substitute(string, pattern, '', 'g')
    endwhile
        let string = substitute(string, pattern, '', 'g')
    endwhile
    return string
endfunction " }}}3

function! s:stripLeadingWhitespace(string) " {{{3
    return substitute(a:string, '^\s*', '', '')
endfunction " }}}3

function! s:breakAroundBegin(string) " {{{3
    let pattern = '^\(.\{-}\)'
    let pattern .= '\(\(%\s*\)\?\\begin{.\{-}}\)'
    let pattern .= '\(.\{-}\)$'
    let before = substitute(a:string, pattern, '\1', '')
    let begin = substitute(a:string, pattern, '\2', '')
    let after = substitute(a:string, pattern, '\4', '')
    return [ before, begin, after ]
endfunction " }}}3

function! s:breakAroundEnd(string) " {{{3
    let pattern = '^\(.\{-}\)'
    let pattern .= '\(\(%\s*\)\?\\end{.\{-}}\)'
    let pattern .= '\(.\{-}\)$'
    let before = substitute(a:string, pattern, '\1', '')
    let begin = substitute(a:string, pattern, '\2', '')
    let after = substitute(a:string, pattern, '\4', '')
    return [ before, begin, after ]
endfunction " }}}3

" }}}2

" Bool checks {{{2

function! s:shouldJoin(line) " {{{3
    return a:line =~ '\a' &&
         \ a:line !~ '\\\(begin\|end\){.\{-}}' &&
         \ !s:isEmptyOrWhitespace(a:line) &&
         \ !s:isSingleBrace(a:line) &&
         \ (!s:isSingleCommand(a:line) ||
            \ !s:startsWithCommand(a:line, 'label'))
endfunction " }}}3

function! s:beginsEnv(line) " {{{3
    return a:line =~ '.*\\begin{\(.\{-}\)}.*'
endfunction " }}}3

function! s:opensBrace(line) " {{{3
    let line = substitute(a:line, '\s*%.*', '', 'g')
    let line = substitute(line, '.\{-}\(.\)$', '\1', '')
    return line =~ '[[{]'
endfunction " }}}3

function! s:bracesAreMatched(string) " {{{3
    let string = s:removeMatchedBraces(a:string)
    return string !~ '[[\]{}]'
endfunction " }}}3

function! s:isEmptyOrWhitespace(string) " {{{3
    return empty(a:string) || a:string !~ '\S'
endfunction " }}}3

function! s:isSingleCommand(string) " {{{3
    if !s:bracesAreMatched(a:string)
        return 0
    endif
    let pattern = '^\s*\\\(.\|[A-Za-z@]\{-}\)\(\[.\{-}\]\)\?'
    let pattern .= '\({.\{-}}\)*\s*\(%.*\)\?$'
    return a:string =~ pattern
endfunction " }}}3

function! s:isSingleBrace(string) " {{{3
    let string = substitute(a:string, '\s*%.*', '', 'g')
    return string =~ '^\s*[\[\]{}]\s*$'
endfunction " }}}3

function! s:startsWithItem(string) " {{{3
    return a:string =~ '^\s*\\item\s'
endfunction " }}}3

function! s:startsWithComment(string) " {{{3
    return a:string =~ '^\s*%'
endfunction " }}}3

function! s:startsWithCommand(string, command) " {{{3
    let pattern = '^\s*\\\(.\{-}\)\([^A-Za-z@]\|$\).*'
    let command = substitute(a:string, pattern, '\1', 'g')
    return command == a:command
endfunction " }}}3

function! s:startsWithSlash(string) " {{{3
    let firstChar = substitute(a:string, '^\(.\).*', '\1', 'g')
    return firstChar == '\'
endfunction " }}}3

function! s:startsWithUppercase(string) " {{{3
    let string = s:removeDiacritics(a:string)
    return string =~ '^\s*\(\\.\{-}{\)\?\u' || string =~ '^\s*\\textcite'
endfunction " }}}3

function! s:endsWithPeriod(string) " {{{3
    return a:string =~ '[.!?]\s*$'
endfunction " }}}3

function! s:shouldFormatComments() " {{{3
    return get(g:, 'bucky_format_comments', 0)
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

function! s:environment(string) " {{{3
    let pattern = '.*\\\(begin\|end\){\(.\{-}\)}.*'
    if match(a:string, pattern) >= 0
        let env = substitute(a:string, pattern, '\2', 'g')
        return env
    else
        return ''
    endif
endfunction " }}}3

function! s:findEnd(list) " {{{3
    let env = escape(s:environment(a:list[0]), '\\/^$.*~[]')
    let i = 0
    let openEnvironments = 0
    while i < len(a:list)
        let line = a:list[i]
        if line =~ '\\begin{' . env . '}'
            let openEnvironments += 1
        endif
        if line =~ '\\end{' . env . '}'
            let openEnvironments -= 1
        endif
        if openEnvironments == 0
            return i
        endif
        let i += 1
    endwhile
    return -1
endfunction " }}}3

function! s:findMatchingBrace(list) " {{{3
    let lines = a:list
    map(lines, 's:removeMatchedBraces(v:val)')
    let firstLine = substitute(lines[0], '\s*%.*', '', 'g')
    let openingBrace = substitute(firstLine, '.\{-}\([\[{]\)$', '\1', '')
    let closingBrace = openingBrace == '[' ? ']' : '}'
    let i = 1
    let openBraces = 1
    while i < len(lines)
        let line = lines[i]
        for char in split(line, '\zs')
            if char == openingBrace
                let openBraces += 1
            elseif char == closingBrace
                let openBraces -= 1
            endif
            if openBraces == 0
                return i
            endif
        endfor
        let i += 1
    endwhile
    return -1
endfunction " }}}3

function! s:findEndOfComment(list) " {{{3
    let i = 1
    while i < len(a:list)
        if !s:startsWithComment(a:list[i])
            return i - 1
        endif
        let i += 1
    endwhile
    return i
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

function! s:sentenceEnvironments() " {{{3
    return get(g:, 'bucky_sentence_environments', '^$')
endfunction " }}}3

" }}}2

" Misc {{{2

function! s:upperOrCommand() " {{{3
    let upper = '\(\u\|[ÁÂÃÀÇÉÊÍÓÔÕÜÚ]\|\\textcite\)'
    let upperOrCommand = '\(' . upper . '\|\\\w\{-}\(\[.\{-}\]\)\?{'
    let upperOrCommand .= upper . '.\{-}}\)'
    return upperOrCommand
endfunction " }}}3

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

