""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Plugins
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if empty(glob('~/.vim/autoload/plug.vim'))
	silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
	\ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
call plug#begin('~/.vim/plugged')
Plug 'scrooloose/nerdcommenter'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'airblade/vim-gitgutter'
call plug#end()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" NERDCommenter
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Toggle comments with CTRL-/
noremap <C-/> :call NERDComment(0, "toggle")<C-m>

" Add spaces after comment delimiters by default
let g:NERDSpaceDelims = 1

" Align line-wise comment delimiters flush left instead of following code indentation
let g:NERDDefaultAlign = 'left'

" Allow commenting and inverting empty lines (useful when commenting a region)
let g:NERDCommentEmptyLines = 1

" Enable trimming of trailing whitespace when uncommenting
let g:NERDTrimTrailingWhitespace = 1

" Enable NERDCommenterToggle to check all selected lines is commented or not 
let g:NERDToggleCheckAllLines = 1

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" File Exploration
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Hide .swp files
let g:netrw_list_hide = '.*\.swp$'
" Hide menu
let netrw_banner = 0

" Open vimrc
command V exec ":e $MYVIMRC"

" Change current working directory
command CD exec ":cd %:p:h"

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Copy and Paste
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Changes copy and paste to use the system clipboard
set clipboard=unnamedplus,unnamed

" Delete and pasting over text does not yank text
nnoremap d "_d
xnoremap d "_d
xnoremap p "_dP

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Windows and Tabs
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Makes new split screens appear below or to the right the current screen
set splitbelow
set splitright

" Quick way to move between windows
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l

" Quick way to resize windows
nnoremap <C-_> <C-w>-
nnoremap <C-=> <C-w>+
nnoremap <C-+> 100<C-w>+

" Quick way to switch tabs
nnoremap <M-n> :tabnew<Space>
nnoremap <M-l> :tabnext<CR>
nnoremap <M-h> :tabprev<CR>
nnoremap <M-k> :tabfirst<CR>
nnoremap <M-j> :tablast<CR>
nnoremap <M-c> :tabclose<CR>
nnoremap <M-q> :tabclose<CR>
nnoremap <M-m> :tabmove<Space>
nnoremap <M-1> 1gt
nnoremap <M-2> 2gt
nnoremap <M-3> 3gt
nnoremap <M-4> 4gt
nnoremap <M-5> 5gt
nnoremap <M-6> 6gt
nnoremap <M-7> 7gt
nnoremap <M-8> 8gt
nnoremap <M-9> 9gt
nnoremap <M-0> :tablast<CR>

" Quick way to move between windows in terminal
tnoremap <C-j> <C-w>j
tnoremap <C-k> <C-w>k
tnoremap <C-h> <C-w>h
tnoremap <C-l> <C-w>l

" Quick way to resize windows
tnoremap <C-_> <C-w>-
tnoremap <C-=> <C-w>+
tnoremap <C-+> <C-w>_

" Open terminal
command T call OpenTerminal()
func! OpenTerminal()
	exec ":terminal"
	exec "normal 5\<C-w>_"
endfunc

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Indentation
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set tabstop=4
set shiftwidth=4

set smartindent

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Appearance and Behavior
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Turn syntax highlighting on
filetype plugin on
syntax on
noh

" Highlight trailing whitespace
set listchars=tab:\ \ ,trail:·,nbsp:_
set list
" autocmd VimEnter,WinEnter * match Error /\v^\t* +\t*[^\s]/

" Get rid of 'Hit ENTER to continue'
set shortmess+=a

" Show line numbers
set nu

" Highlight line overflow
autocmd VimEnter,WinEnter * call matchadd('ColorColumn', '\%81v', 100)

" Backspace deletes lines
set backspace=indent,eol,start

" Lets cursor go one space past the end of the line
set virtualedit=onemore

" Stops creation of backup files (.un~, .file~)
set noundofile
set nobackup
set nowritebackup

" Move cursor by display lines when line is wrapped
nnoremap j gj
nnoremap k gk
vnoremap j gj
vnoremap k gk
nnoremap <Down> gj
nnoremap <Up> gk
vnoremap <Down> gj
vnoremap <Up> gk
inoremap <Down> <C-o>gj
inoremap <Up> <C-o>gk

" These create newlines like o and O but stay in normal mode
nnoremap zj o<Esc>k
nnoremap zk O<Esc>j
