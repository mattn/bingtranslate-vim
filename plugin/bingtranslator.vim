" vim:set ts=8 sts=2 sw=2 tw=0:
"
" bindtranslate.vim - Translate between English and Locale Language
" using Bind Translator
" @see [http://www.bing.com/developers/appids.aspx Bing Developer Center]
"
" Author:       Yasuhiro Matsumoto <mattn.jp@gmail.com>
" Last Change:  24-Mar-2011.

if !exists('g:bingtranslate_options')
  let g:bingtranslate_options = ["register","buffer"]
endif
" default language setting.
if !exists('g:bingtranslate_locale')
  let g:bingtranslate_locale = split(v:lang, '[_\.]')[0]
endif

let s:endpoint = 'http://api.microsofttranslator.com/V2/Ajax.svc/Translate'

function! s:CheckLang(word)
  let all = strlen(a:word)
  let eng = strlen(substitute(a:word, '[^\t -~]', '', 'g'))
  return eng * 2 < all ? '' : 'en'
endfunction

function! s:nr2byte(nr)
  if a:nr < 0x80
    return nr2char(a:nr)
  elseif a:nr < 0x800
    return nr2char(a:nr/64+192).nr2char(a:nr%64+128)
  else
    return nr2char(a:nr/4096%16+224).nr2char(a:nr/64%64+128).nr2char(a:nr%64+128)
  endif
endfunction

function! s:nr2enc_char(charcode)
  if &encoding == 'utf-8'
    return nr2char(a:charcode)
  endif
  let char = s:nr2byte(a:charcode)
  if strlen(char) > 1
    let char = strtrans(iconv(char, 'utf-8', &encoding))
  endif
  return char
endfunction

" @see http://vim.g.hatena.ne.jp/eclipse-a/20080707/1215395816
function! s:char2hex(c)
  if a:c =~# '^[:cntrl:]$' | return '' | endif
  let r = ''
  for i in range(strlen(a:c))
    let r .= printf('%%%02X', char2nr(a:c[i]))
  endfor
  return r
endfunction
function! s:encodeURI(s)
  return substitute(a:s, '[^0-9A-Za-z-._~!''()*#$&+,/:;=?@]',
        \ '\=s:char2hex(submatch(0))', 'g')
endfunction
function! s:encodeURIComponent(s)
  return substitute(a:s, '[^0-9A-Za-z-._~!''()*]',
        \ '\=s:char2hex(submatch(0))', 'g')
endfunction

function! BingTranslate(word, from, to)
  if !executable("curl")
    echohl WarningMsg
    echo "BingTranslate require 'curl' command."
    echohl None
    return
  endif
  if !exists('g:bingtranslate_appid')
    echohl WarningMsg
    echo "Does not set g:bingtranslate_appid"
    echohl None
    return
  endif

  let query = [
    \ 'appId=%s',
    \ 'to=%s',
    \ 'from=%s',
    \ 'text=%s',
    \ ]
  let squery = printf(join(query, '&'),
    \ s:encodeURI(g:bingtranslate_appid),
    \ s:encodeURI(a:to),
    \ s:encodeURI(a:from),
    \ s:encodeURI(a:word))
  unlet query
  let quote = &shellxquote == '"' ?  "'" : '"'
  let text = system('curl -s '.quote.s:endpoint.'?'.squery.quote)
  if char2nr(text[0]) == 0xef && char2nr(text[1]) == 0xbb && char2nr(text[2]) == 0xbf
    let text = text[3:] " cut BOM
  endif
  let text = iconv(text, "utf-8", &encoding)
  let text = substitute(text, '\\u\(\x\x\x\x\)', '\=s:nr2enc_char("0x".submatch(1))', 'g')
  let str = eval(text)
  return str
endfunction

function! BingTranslateRange(...) range
  " Concatenate input string.
  let curline = a:firstline
  let strline = ''

  if a:0 >= 3
    let strline = a:3
  else
    while curline <= a:lastline
      let tmpline = substitute(getline(curline), '^\s\+\|\s\+$', '', 'g')
      if tmpline=~ '\m^\a' && strline =~ '\m\a$'
        let strline = strline .' '. tmpline
      else
        let strline = strline . tmpline
      endif
      let curline = curline + 1
    endwhile
  endif

  let from = ''
  let to = g:bingtranslate_locale
  if a:0 == 0
    let from = s:CheckLang(strline)
    let to = 'en'==from ? g:bingtranslate_locale : 'en'
  elseif a:0 == 1
    let to = a:1
  elseif a:0 >= 2
    let from = a:1
    let to = a:2
  endif

  " Do translate.
  let jstr = BingTranslate(strline, from, to)
  if len(jstr) == 0
    return
  endif

  " Echo
  if index(g:bingtranslate_options, 'echo') != -1
    echo jstr
  endif
  " Put to buffer.
  if index(g:bingtranslate_options, 'buffer') != -1
    " Open or go result buffer.
    let bufname = '==Bing Translate=='
    let winnr = bufwinnr(bufname)
    if winnr < 1
      silent execute 'below 10new '.escape(bufname, ' ')
      nmap <buffer> q :<c-g><c-u>bw!<cr>
      vmap <buffer> q :<c-g><c-u>bw!<cr>
    else
      if winnr != winnr()
        execute winnr.'wincmd w'
      endif
    endif
    setlocal buftype=nofile bufhidden=hide noswapfile wrap ft=
    " Append translated string.
    if line('$') == 1 && getline('$').'X' ==# 'X'
      call setline(1, jstr)
    else
      call append(line('$'), '--------')
      call append(line('$'), jstr)
    endif
    normal! Gzt
  endif
  " Put to unnamed register.
  if index(g:bingtranslate_options, 'register') != -1
    let @" = jstr
  endif
endfunction

command! -nargs=* -range BingTranslate <line1>,<line2>call BingTranslateRange(<f-args>)
