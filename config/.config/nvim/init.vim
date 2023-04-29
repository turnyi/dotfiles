:set smarttab
:set number
:set tabstop=4
:set relativenumber
:set autoindent
:set shiftwidth=4
:set softtabstop=4
:set mouse=a
:set autoindent                          " Inherit indentation from previous line.
:set autoread                            " Reload the file when external changes are detected
:set autowriteall                        " Work with buffers
:set backspace=indent,eol,start          " Fixes common backspace problems.
:set cindent
:set clipboard=unnamedplus               " Using system clipboard
:set cmdheight=1                         " Give more space for displaying messages
:set completeopt=longest,menuone,preview " Make the completion menu behave like an IDE
:set conceallevel=0                      " Makes `` visible on markdown files.
:set confirm                             " Makes it easier to
:set exrc                                " Source coniguration every time I enter a new project
:set fileencoding=utf-8                  " Use utf-8 as encoding type for files.
:set guicursor+=
:set hidden                              " Keeps any buffer available
:set hlsearch                            " Highlight search
:set incsearch                           " Incremental search
:set matchpairs+=<:>                     " Highlight matching pairs of branckets.
:set mouse=a                             " Enable mouse click
:set nobackup                            " Don't backup files
:set nocompatible                        " Disable compatibility to old-time vi
:set noerrorbells                        " Disable error bells sounds
:set nofoldenable                        " Deactivate fold use command.
:set belloff=all                         " Disable all system bells
:set nohlsearch                          " Hide the search highlight after present enter
:set noignorecase                        " Case sensitive searches
:set noshowmode                          " Remove --INSERT-- and similar text from the message line.
:set noswapfile                          " Disable the use of swapfiles
:set nowrap                              " Disable line wraping
:set nowritebackup                       " Don't write backups.
:set number                              " Add line numbers
:set numberwidth=4                       " Set number width to 4 (default: 2)
:set pumheight=10                        " Pop up menu height
:set re=0                                " Stop old regex engine to avoid performance loss.
:set relativenumber                    " Un-set relative numbers
:set ruler                               " Enable line and column display
:set scrolloff=8                         " Make vim start scrolling 8 lines from the end
:set shortmess=F                         " Don't pass messages to |ins-completion-menu|
:set showmatch                           " Show matching
:set signcolumn=yes
:set smartindent
:set splitbelow                          " Split panes to the bottom
:set splitright                          " Split panes to the right
:set termguicolors                       " Use terminal GUI colors.
:set timeoutlen=1000                     " Update the time between multiple key presses
:set ttyfast                             " Speed up scrolling on vim
:set undodir=~/.vim/undodir              " Sets the location of the undo dir.
:set undofile                            " Used with plugins. Need for research.
:set updatetime=300                      " Increase the update time
:set vb t_vb=                            " Disable Beep/Flash
:set wildmenu
:set wildmode=longest,list               " Get bash-like tab completions
:set laststatus=3                        " Show global statusline
:set ofu=syntaxcomplete#Complete         " Enable omnicompletion for syntax
:set softtabstop=2                       " Soft tab size
:set tabstop=2                           " Tab size
:set expandtab                           " Replace tabs with spaces
:set shiftwidth=2                        " Visual mode indentation (match tabstop)
:set foldmethod=expr                     " Kind of fold used for the current window.
:set foldexpr=nvim_treesitter#foldexpr() " Use Treesitter to handle folds

source ~/.config/nvim/plug.vim

call plug#begin('~/.config/nvim/my-plugins/')
Plug 'https://github.com/joshdick/onedark.vim'
Plug 'http://github.com/tpope/vim-surround' " Surrounding ysw)
Plug 'https://github.com/preservim/nerdtree' " NerdTree
Plug 'https://github.com/tpope/vim-commentary' " For Commenting gcc & gc
Plug 'https://github.com/vim-airline/vim-airline' " Status bar
Plug 'vim-airline/vim-airline-themes'
Plug 'https://github.com/lifepillar/pgsql.vim' " PSQL Pluging needs :SQLSetType pgsql.vim
Plug 'https://github.com/ap/vim-css-color' " CSS Color Preview
Plug 'https://github.com/rafi/awesome-vim-colorschemes' " Retro Scheme
Plug 'https://github.com/ryanoasis/vim-devicons' " Developer Icons
Plug 'https://github.com/tc50cal/vim-terminal' " Vim Terminal
Plug 'https://github.com/terryma/vim-multiple-cursors' " CTRL + N for multiple cursors
Plug 'https://github.com/preservim/tagbar' " Tagbar for code navigation
Plug 'https://github.com/neoclide/coc.nvim'  " Auto Completion
Plug 'https://github.com/github/copilot.vim.git' " Copilot1
Plug 'https://github.com/andviro/flake8-vim.git' " Flake8
Plug 'ambv/black' " Black
Plug 'eslint/eslint' "eslint
Plug 'sbdchd/neoformat' " Neoformat
Plug 'neomake/neomake'
Plug 'neovim/nvim-lspconfig' " lsp plug languages
Plug 'nvim-lua/lsp-status.nvim'
Plug 'hrsh7th/nvim-compe'
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'williamboman/nvim-lsp-installer'
Plug 'f-person/git-blame.nvim'
Plug 'dyng/ctrlsf.vim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.1' }
Plug 'junegunn/fzf.vim'
Plug 'jose-elias-alvarez/null-ls.nvim'
Plug 'othree/html5.vim'
Plug 'mustache/vim-mustache-handlebars',
Plug 'pangloss/vim-javascript',
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'sheerun/vim-polyglot'

call plug#end()


" ctrlp show hidden files
let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files -co --exclude-standard']
let g:ctrlp_show_hidden = 1

:set completeopt-=preview " For No Preview

" Enable Coc on normal mode
nmap <silent><leader>g <Plug>(coc-cmd)


" Set keybinds 
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-b> :NERDTreeToggle<CR>
nnoremap <C-l> :call CocActionAsync('jumpDefinition')<CR>
nnoremap <C-s> :w<CR>  " save with ctrl+s
vnoremap <silent><c-s> <c-c>:update<cr>gv
inoremap <silent><c-s> <c-o>:update<cr>
nmap <F8> :TagbarToggle<CR>
cnoremap <C-:> :q<CR>


" Move line upwards with Alt + Up Arrow in normal and insert mode
nnoremap <A-Up> :m-2<CR>
nnoremap <A-k> :m-2<CR>
inoremap <A-Up> <Esc>:m-2<CR>a

" Move line Downwards with Alt + down Arrow in normal and insert mode
nnoremap <A-Down> :m+<CR>
nnoremap <A-j> :m+<CR>
inoremap <A-Down> <Esc>:m+<CR>a

set termguicolors
syntax on
colorscheme onedark

inoremap <expr> <Tab> pumvisible() ? coc#_select_confirm() : "<Tab>"
set fillchars+=eob:\ " remove ~ from empty lines:
set wildmenu

" NerdTree config:
let g:NERDTreeShowHidden=1
let g:NERDTreeWinPos = "right"

" Telescope command line:
" Find files using Telescope command-line sugar.
" nnoremap <leader>ff <cmd>Telescope find_files hidden=true<cr>
" nnoremap <C-p> <cmd>Telescope find_files hidden=true<cr>
" nnoremap <leader>fg <cmd>Telescope live_grep<cr>
" nnoremap <leader>fb <cmd>Telescope buffers<cr>
" nnoremap <leader>fh <cmd>Telescope help_tags<cr>

" Find files using Telescope command-line sugar.
nnoremap <leader>ff <cmd>Telescope find_files hidden=true<cr>
nnoremap <C-p> <cmd>Telescope find_files hidden=true<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <C-S-f> <cmd>Telescope live_grep hidden=true<cr>
nnoremap <C-f> :Telescope current_buffer_fuzzy_find<CR>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>

nnoremap <C-n> :call CreateFile()<CR>

function! CreateFile()
  let filename = input("Enter filename: ")
  execute "e " . expand("%:p:h") . "/" . filename
endfunction

"source ~/.config/nvim/setup.lua
