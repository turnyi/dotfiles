:set smarttab
:set number
:set tabstop=4
:set relativenumber
:set autoindent
:set shiftwidth=4
:set softtabstop=4
:set mouse=a

source ~/.config/nvim/plug.vim
call plug#begin('~/.config/nvim/my-plugins/')
Plug 'http://github.com/tpope/vim-surround' " Surrounding ysw)
Plug 'https://github.com/preservim/nerdtree' " NerdTree
Plug 'https://github.com/tpope/vim-commentary' " For Commenting gcc & gc
Plug 'https://github.com/vim-airline/vim-airline' " Status bar
Plug 'https://github.com/lifepillar/pgsql.vim' " PSQL Pluging needs :SQLSetType pgsql.vim
Plug 'https://github.com/ap/vim-css-color' " CSS Color Preview
Plug 'https://github.com/rafi/awesome-vim-colorschemes' " Retro Scheme
Plug 'https://github.com/ryanoasis/vim-devicons' " Developer Icons
Plug 'https://github.com/tc50cal/vim-terminal' " Vim Terminal
Plug 'https://github.com/terryma/vim-multiple-cursors' " CTRL + N for multiple cursors
Plug 'https://github.com/preservim/tagbar' " Tagbar for code navigation
Plug 'https://github.com/neoclide/coc.nvim'  " Auto Completion
Plug 'https://github.com/kien/ctrlp.vim' " ctrlp search

call plug#end()

" Set keybinds 
nnoremap <C-f> :NERDTreeFocus<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-b> :NERDTreeToggle<CR>
nnoremap <C-l> :call CocActionAsync('jumpDefinition')<CR>
nnoremap <C-s> :w<CR>  " save with ctrl+s
vnoremap <silent><c-s> <c-c>:update<cr>gv
inoremap <silent><c-s> <c-o>:update<cr>
nmap <F8> :TagbarToggle<CR>

" Move line upwards with Alt + Up Arrow in normal and insert mode
nnoremap <A-Up> :m-2<CR>
nnoremap <A-k> :m-2<CR>
inoremap <A-Up> <Esc>:m-2<CR>a

" Move line upwards with Alt + down Arrow in normal and insert mode
nnoremap <A-Down> :m+<CR>
nnoremap <A-j> :m+<CR>
inoremap <A-Down> <Esc>:m+<CR>a



:set completeopt-=preview " For No Previews
:colorscheme jellybeans

inoremap <expr> <Tab> pumvisible() ? coc#_select_confirm() : "<Tab>"
set fillchars+=eob:\ " remove ~ from empty lines:

" NerdTree config:
let g:NERDTreeShowHidden=1
let g:NERDTreeWinPos = "right"
