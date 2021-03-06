" File: win.vim
" Author: romgrk
" Description: windows functions
" Date: 15 Mar 2016
" !::exe [so %]

if exists('did_win_vim')
    if get(g:, 'debug', 0)
        call Warn('Reloading')
        let g:_win = s:
        for nr in range(winnr('$'))
            call win#cmd(nr, ['unlet! w:w_object', 'unlet! w:w_hash'])
            call win#(nr)
        endfor
    else
        finish | end
end
let did_win_vim = 1

unlet! s:map
unlet! s:filters
let s:map = {}
let s:filters = {
\ 'listed': "getwinvar(v:val, '&buflisted')",
\ 'term':   "win#type(v:val) == 'terminal'",
\ }

au VimEnter * nested call <SID>init()
function! s:init ()
    execute 'augroup ' . expand('<sfile')
        au!
        au WinLeave * call <SID>winLeave()
        au WinEnter * call <SID>winEnter()
    augroup END
endfunction " }}}

let s:windowCount = 0
let s:closedWindows = []

function! s:winEnter () " {{{
    if !exists('w:w_hash')
        call win#()
        call s:update()
        return
    end
    if s:windowCount != winnr('$')
        let s:windowCount = winnr('$')
        "call EchoHL('TextWarning', "Window count changed! (", s:windowCount, ")")
        call s:update()
    endif
endfunc "  }}}
function! s:winLeave () " {{{
    let hash = get(w:, 'w_hash', 0)
    if !hash | return | endif
    if !exists('s:map[l:hash]') | return  | end
    let win = s:map[hash]
    let win.data = {'bufnr': win.bufnr(), 'size':[win.width(), win.height()]}
endfunc " }}}
function! s:update (...) " {{{
    try
        for h in keys(s:map)
            let win = s:map[h]
            call win.exists()
        endfor
        for winID in range(1, winnr('$'))
            let hash = getwinvar(winID, 'w_hash')
            if empty(hash)
                "call EchoHL('TextWarning', 'Window with no hash: ', winID)
                call win#(winID)
            else
                let s:map[hash].winnr = winID | end
        endfor
        for h in keys(s:map)
            let win = s:map[h]
            if win.winnr == -1
                call remove(s:map, h)
                "call EchoHL('TextInfo', 'remove ', string(win))
            endif
        endfor
    catch /.*/
        "call EchoHL('TextError', 'Error while updating: ' . v:exception)
    endtry
endfunc " }}}

" class Window
" (), (0), ('.'), ('%') => current window
" ('$')              => last window                 ('#')      => previous window
" ({Number})         => window {Number}             ('b' . nr) => window for buffer {nr}
let s:Window = {}
function! win# (...) " {{{
    if empty(a:000)
        let winnr = winnr()
    elseif type(a:1) is type('string')
        if a:1[0:0] == 'b'
            let winnr = bufwinnr(a:1[1:] + 0)
        elseif a:1 == '.'
            let winnr = winnr()
        else
            let winnr = winnr(a:1) " $ or #
        end
    elseif type(a:1) is type([])
        let list = call('win#list', a:1)
        if (len(list) == 0)
            return list | endif
        let limit = (exists('a:2') ? a:2 : len(list))
        return list[:(limit-1)]
    else
        let winnr = a:1
    end

    if winnr > winnr('$') || winnr <= 0
        echohl ErrorMsg
        echo 'Window ' . winnr . ' doesnt exist'
        echohl None
        return
    end

    " Check for Window(winnr) in HashMap
    let hash = getwinvar(winnr, 'w_hash')
    if  hash != '' && exists('s:map[l:hash]')
        let win = s:map[hash]
        let win.nr = winnr
        let win.winnr = winnr
        return win
    endif

    " Create new object
    return s:newWindow(winnr)
endfunc " }}}

function! s:newWindow (nr) " {{{
    let w_object = win#info(a:nr)
    call extend(w_object, deepcopy(s:Window))
    let hash = string(reltime())
    let s:map[hash]   = w_object
    let w:w_object    = w_object
    let w:w_hash      = hash
    let w_object.hash = hash
    return w_object
endfunction " }}}
function! s:Window.b (...) dict " {{{
    if a:0==1 | return getbufvar(winbufnr(self.winnr), a:1)
    else    | call setbufvar(winbufnr(self.winnr), a:1, a:2) | end
endfunc " }}}
function! s:Window.w (...) dict " {{{
    if a:0==1 | return getwinvar(self.winnr, a:1)
    else    | call setwinvar(self.winnr, a:1, a:2) | end
endfunc " }}}
function! s:Window.buf (...) dict " {{{
    if !a:0 | return buf#(self.bufnr())
    else    | call win#cmd(self.winnr, 'b' . a:1.nr) | end
endfunction " }}}
function! s:Window.bufnr (...) dict " {{{
    if !a:0 | return winbufnr(self.winnr)
    else    | call win#cmd(self.winnr, 'b' . a:1) | end
endfunction " }}}
function! s:Window.bufname (...) dict " {{{
    if !a:0 | return bufname(winbufnr(self.winnr))
    else    | exe 'file ' . a:1                    | end
endfunc " }}}
function! s:Window.buftype (...) dict " {{{
    if !a:0 | return getbufvar(winbufnr(self.winnr), '&buftype')
    else    | call setbufvar(winbufnr(self.winnr), '&buftype', a:1) | end
endfunc " }}}
function! s:Window.listed (...) dict " {{{
    if !a:0 | return getbufvar(winbufnr(self.winnr), '&buflisted')
    else    | call setbufvar(winbufnr(self.winnr), '&buflisted', a:1) | end
endfunc " }}}
function! s:Window.ft (...) dict " {{{
    if !a:0 | return getbufvar(winbufnr(self.winnr), '&ft')
    else    | call setbufvar(winbufnr(self.winnr), '&ft', a:1) | end
endfunc " }}}
function! s:Window.height (...) dict " {{{
    if !a:0 | return winheight(self.winnr)
    else    | call self.resize('', a:1)    | end
endfunc " }}}
function! s:Window.width (...) dict " {{{
    if !a:0 | return winwidth(self.winnr)
    else | call self.resize(a:1, '') | end
endfunc " }}}
function! s:Window.resize (w, h) dict " {{{
    if type(a:w)!=1 || !empty(a:w)
        exe 'vertical ' . self.winnr . ' resize ' . a:w
    end
    if type(a:h)!=1 || !empty(a:h)
        exe self.winnr . ' resize ' . a:h
    end
endfunc " }}}
function! s:Window.cmd (cmd) dict " {{{
    return win#cmd(self.winnr, a:cmd)
endfunc " }}}
function! s:Window.exists () dict " {{{
    if self.winnr == -1 | return 0 | endif
    let ex = (self.hash ==# getwinvar(self.winnr, 'w_hash'))
    if !ex | let self.winnr = -1 | endif
    return ex
endfunc " }}}
function! s:Window.hasFocus () dict " {{{
    return winnr() == self.winnr
endfunc " }}}
function! s:Window.focus () dict " {{{
    execute self.winnr . 'wincmd w'
endfunc " }}}
function! s:Window.blur () dict " {{{
    if self.hasFocus()
        wincmd p
        if self.hasFocus()
            wincmd w | end
    end
endfunc " }}}
function! s:Window.display (...) dict " ({Number|String|Buffer}, focus) {{{
    call call(self.open, a:000, self)
endfunc " }}}
function! s:Window.open (buf, ...) dict " ({Number|String|Buffer}, focus) {{{
    if type(a:buf) == 0
        call win#cmd(self.winnr, 'b' . a:buf)
    elseif type(a:buf) == 1
        call win#cmd(self.winnr, 'b' . bufnr(a:buf))
    elseif type(a:buf) == 3
        throw "win.open: called with list: ". string(a:buf)
        "call win#cmd(self.winnr, )
    elseif type(a:buf) == 4
        call win#cmd(self.winnr, 'b' . a:buf['nr'])
    end
    if get(a:, 2, 0)
        call self.focus()
    endif
endfunction " }}}
function! s:Window.close (...) dict " {{{
    call win#close(self.nr)
endfunction " }}}

" Static functions
function! win#first (...) " {{{
    let fun = (type(a:1) == 3) ? 'win#list' : 'win#filter'
    let args = (type(a:1) == 3) ? a:1 : a:000
    return s:f(fun, args)
endfunc " }}}
function! win#sort (compare, ...) " {{{
    let fun  = (type(a:1) == 3) ? 'win#list' : 'win#filter'
    let args = (type(a:1) == 3) ? a:1 : a:000
    if type(args[0])==0
        let current = args[0]
        let args    = args[1:]
    else
        let current = winnr()  | end
    let list = s:c(fun, args)
    if empty(list)  | return -1 | end
    if fun ==# 'win#list'
        call map(list, 'v:val.winnr') | end
    let first = list[0]
    if len(list)==1 | return first | end
    call filter(list, a:compare . current)
    if empty(list)
        return first
    else
        return list[0] |end
endfunc " }}}
function! win#previous (...) " {{{
    return s:c('win#sort', ['v:val < '] + a:000)
endfunc " }}}
function! win#next (...) " {{{
    return s:c('win#sort', ['v:val > '] + a:000)
endfunc " }}}
function! win#list (...) " {{{
    let list = range(1, winnr('$'))
    for f in a:000
        if exists('s:filters[l:f]')
            call filter(list, s:filters[f])
            call map(list, 'win#(v:val)')
        else
            call map(list, 'win#(v:val)')
            call filter(list, f)                  | endif
    endfor
    return list
endfunction " }}}
function! win#filter (...) " {{{
    let list = range(1, winnr('$'))
    for a_expr in a:000
        let expr = a_expr
        let expr = substitute(expr, '&\w\+', 'getwinvar(v:val, "\0")', 'g')
        if exists('s:filters[l:expr]')
            call filter(list, s:filters[l:expr])  | else
            call filter(list, expr)                     | end
    endfor
    return list
endfunction " }}}
function! win#type (...) " {{{
    let winID = (a:0) ? a:1 : winnr()
    if type(winID) == 4
        return winID.buftype()
    end
    let bufnr = winbufnr(winID)
    return getbufvar(bufnr, '&buftype')
endfu
function! win#info (...) " {{{
    let winID = (a:0) ? a:1 : winnr()
    let bufnr = winbufnr(winID)
    return {'nr': winID, 'winnr': winID, 'bufnr': bufnr,
    \ 'height': winheight(winID),
    \ 'width': winwidth(winID),
    \ 'listed': buflisted(bufnr),
    \ 'type': getbufvar(bufnr, '&buftype'),
    \ 'ft': getbufvar(bufnr, '&ft'),
    \ }
    "\ 'resize': function('s:resize')
endfunc " }}}
function! win#new (...) " {{{
    let pos     = a:1
    let cmdList = a:2

    exe pos . 'wincmd n'
    let win = win#()

    for cmd in cmdList
        exe cmd
    endfor

    call s:update()
    return win
endfunc " }}}
function! win#split (...) " {{{
    let pos     = a:1
    let cmdList = a:2

    exe pos . ' split'
    let win = win#()

    for cmd in cmdList
        exe cmd
    endfor

    call s:update()
    return win
endfunc " }}}
function! win#cmd (winID, ...) " {{{
    let saved_window = winnr()
    let saved_ei = &ei
    "set eventignore=WinEnter,WinLeave
    set eventignore=all
    for cmd in a:000
        exe a:winID . 'windo ' . cmd
    endfor
    exe saved_window . 'wincmd w'
    let &ei = saved_ei
endfunc " }}}
function! win#close (...) " [nr] {{{
    let winID = (a:0) ? a:1 : winnr()
    exe winID . 'wincmd c'
endfunc " }}}


" Helpers
function! s:c (...) " {{{
    if (a:0==1) | return call(a:1, [])
    else        | return call(a:1, a:2) | end
endfunc "}}}
function! s:f (...) " => get first element of func():List or -1 {{{
    if (a:0==1) | return get(call(a:1, []), 0, -1)
    else        | return get(call(a:1, a:2), 0, -1) | end
endfunc "}}}


