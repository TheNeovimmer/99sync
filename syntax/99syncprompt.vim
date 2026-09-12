" Syntax file for 99sync prompt window
" Highlights #rules in cyan and @files in goldenrod

if exists("b:current_syntax")
  finish
endif

syntax match 99syncRuleRef /#\S\+/
syntax match 99syncFileRef /@\S\+/

highlight default 99syncRuleRef guifg=#00FFFF ctermfg=cyan
highlight default 99syncFileRef guifg=#DAA520 ctermfg=178

let b:current_syntax = "99syncprompt"
