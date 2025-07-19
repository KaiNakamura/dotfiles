""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" File Exploration
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Hide .swp files
let g:netrw_list_hide = '.*\.swp$'
" Hide menu
let netrw_banner = 0

" Open vimrc
command V exec ":e $MYVIMRC"

" Refresh vimrc
command RV exec ":source $MYVIMRC"

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

" Open splits
nnoremap <C-i> :vsplit<CR>
nnoremap <C-o> :split<CR>

" Close window
nnoremap <C-q> :close<CR>

" Move between windows
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
tnoremap <C-h> <C-w>h
tnoremap <C-j> <C-w>j
tnoremap <C-k> <C-w>k
tnoremap <C-l> <C-w>l

" Switch tabs
nnoremap <M-n> :tabnew<CR>
nnoremap <M-q> :tabclose<CR>
nnoremap <M-l> :tabnext<CR>
nnoremap <M-h> :tabprev<CR>
nnoremap <M-1> 1gt
nnoremap <M-2> 2gt
nnoremap <M-3> 3gt
nnoremap <M-4> 4gt
nnoremap <M-5> 5gt
nnoremap <M-6> 6gt
nnoremap <M-7> 7gt
nnoremap <M-8> 8gt
nnoremap <M-9> 9gt

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

" Show line numbers
set nu

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

