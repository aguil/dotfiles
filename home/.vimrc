" Prevent vim from emulating vi
set nocompatible

" More natural split opening
set splitbelow
set splitright

filetype off  " required for Vundle

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" let Vundle manage Vundle
" required! 
Bundle 'gmarik/vundle'

" My Bundles:
" Bundle 'Lokaltog/powerline', {'rtp': 'powerline/bindings/vim/'}
Bundle 'airblade/vim-gitgutter'
Bundle 'bufexplorer.zip'
Bundle 'davidhalter/jedi-vim'
Bundle 'tpope/vim-fugitive.git'
Bundle 'kien/ctrlp.vim'
Bundle 'klen/python-mode'
Bundle 'scrooloose/nerdtree'
Bundle 'tpope/vim-fugitive'
Bundle 'plasticboy/vim-markdown'
Bundle 'git://git.wincent.com/command-t.git'
Bundle 'christoomey/vim-tmux-navigator'
Bundle 'dart-lang/dart-vim-plugin'
Bundle 'elmcast/elm-vim'

filetype plugin indent on

python from powerline.vim import setup as powerline_setup
python powerline_setup()
python del powerline_setup

" Powerline setup
set guifont=Inconsolata\ for\ Powerline:h16
set laststatus=2

" add export TERM=xterm-256color to your .bashrc or .zshrc
if filereadable (expand("$HOME/.vim/colors/zenburn.vim"))
colorscheme zenburn
let g:zenburn_force_dark_Background=1
endif
"set guifont=Inconsolata:h16
"set guifont=Consolas:h16

" Change cursor shape in different modes
" (for iTerm2 on OS X)
let &t_SI = "\<Esc>]50;CursorShape=1\x7"
let &t_EI = "\<Esc>]50;CursorShape=0\x7"
"
" (for tmux running in iTerm2 on OS X)
"let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
"let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"

" Show line numbers
set number
set ruler

" Show whitespace
set listchars=tab:>.,trail:.,nbsp:.,extends:>,precedes:<
set list

" Syntax highlighting
syntax on

" Set automatic indentation
set autoindent
set smartindent

" Wrap at word boundaries.
set textwidth=79
set formatoptions+=t

" Set tabs at 4 spaces
set tabstop=4
set shiftwidth=2
set expandtab

" Show matching [] and {}
set showmatch

" Set title of window to file name
" set title

" Toggle paste
set pastetoggle=

augroup vimrc_autocmds
    autocmd!
    " highlight characters past column 120
    autocmd FileType python highlight Excess ctermbg=DarkGrey guibg=Black
    autocmd FileType python match Excess /\%79v.*/
    autocmd FileType python set nowrap
augroup END

" Python-mode
" Activate rope
" Keys:
" K             Show python docs
" <Ctrl-Space>  Rope autocomplete
" <Ctrl-c>g     Rope goto definition
" <Ctrl-c>d     Rope show documentation
" <Ctrl-c>f     Rope find occurrences
" <Leader>b     Set, unset breakpoint (g:pymode_breakpoint enabled)
" [[            Jump on previous class or function (normal, visual, operator modes)
" ]]            Jump on next class or function (normal, visual, operator modes)
" [M            Jump on previous class or method (normal, visual, operator modes)
" ]M            Jump on next class or method (normal, visual, operator modes)
let g:pymode_rope = 1

" Auto create and open ropeproject
let g:pymode_rope_auto_project = 1

" Enable autoimport
let g:pymode_rope_enable_autoimport = 1

" Auto generate global cache
let g:pymode_rope_autoimport_generate = 1

" Documentation
let g:pymode_doc = 1
let g:pymode_doc_key = 'K'

"Linting
let g:pymode_lint = 1
let g:pymode_lint_checker = "pyflakes,pep8"
" Auto check on save
let g:pymode_lint_write = 1

" Support virtualenv
let g:pymode_virtualenv = 1

" Enable breakpoints plugin
let g:pymode_breakpoint = 1
let g:pymode_breakpoint_key = '<leader>b'

" syntax highlighting
let g:pymode_syntax = 1
let g:pymode_syntax_all = 1
let g:pymode_syntax_indent_errors = g:pymode_syntax_all
let g:pymode_syntax_space_errors = g:pymode_syntax_all

" Don't autofold code
let g:pymode_folding = 0

" END Python mode

let g:vim_markdown_folding_disabled=0

" Set shell to bash
set shell=/bin/bash

" enable asciidoc syntax highlighting
set syntax=asciidoc
