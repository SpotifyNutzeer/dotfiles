" ── Plugins (vim-plug) ──────────────────────────────────────────
call plug#begin('~/.vim/plugged')

Plug 'catppuccin/vim', { 'as': 'catppuccin' }
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

call plug#end()

" ── Theme ───────────────────────────────────────────────────────
set termguicolors
syntax on

" Transparenter Hintergrund passend zum transparenten Terminal.
" Per Autocmd, damit es ein :colorscheme-Reload überlebt.
augroup TransparentBackground
  autocmd!
  autocmd ColorScheme * highlight Normal       guibg=NONE ctermbg=NONE
  autocmd ColorScheme * highlight NormalNC     guibg=NONE ctermbg=NONE
  autocmd ColorScheme * highlight NonText      guibg=NONE ctermbg=NONE
  autocmd ColorScheme * highlight EndOfBuffer  guibg=NONE ctermbg=NONE
  autocmd ColorScheme * highlight SignColumn   guibg=NONE ctermbg=NONE
  autocmd ColorScheme * highlight LineNr       guibg=NONE ctermbg=NONE
  autocmd ColorScheme * highlight CursorLineNr guibg=NONE ctermbg=NONE
  autocmd ColorScheme * highlight FoldColumn   guibg=NONE ctermbg=NONE
augroup END

silent! colorscheme catppuccin_mocha

" ── Airline (Powerline-Statusbar) ───────────────────────────────
let g:airline_theme = 'catppuccin_mocha'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail'
set laststatus=2
set noshowmode

" ── Sensible Defaults ───────────────────────────────────────────
set nocompatible
filetype plugin indent on

" UI
set number relativenumber
set cursorline
set ruler
set showcmd
set wildmenu
set scrolloff=8
set sidescrolloff=8
set signcolumn=yes
set colorcolumn=100

" Editing
set tabstop=4 shiftwidth=4 softtabstop=4 expandtab
set smartindent autoindent
set backspace=indent,eol,start
set wrap linebreak

" Search
set ignorecase smartcase incsearch hlsearch

" Splits
set splitright splitbelow

" Files
set hidden
set autoread
set undofile
set undodir=~/.vim/undo
set noswapfile
set nobackup

" Performance / UX
set updatetime=250
set timeoutlen=500
set lazyredraw
set mouse=a
set clipboard=unnamedplus
set encoding=utf-8

" Folding
set foldmethod=indent
set foldlevelstart=99

" ── Keymaps ─────────────────────────────────────────────────────
let mapleader = " "
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>h :nohlsearch<CR>
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Undo-Verzeichnis sicherstellen
if !isdirectory(expand('~/.vim/undo'))
  call mkdir(expand('~/.vim/undo'), 'p')
endif
