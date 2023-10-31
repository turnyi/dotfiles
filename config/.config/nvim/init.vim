:set smarttab
:set number
:set tabstop=4
:set breakindent
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
:set timeoutlen=500                     " Update the time between multiple key presses
:set ttyfast                             " Speed up scrolling on vim
:set undodir=~/.vim/undodir              " Sets the location of the undo dir.
:set undofile                            " Used with plugins. Need for research.init.vim
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
:set pumblend=0                         " Popup menu transparency

source ~/.config/nvim/plug.vim

call plug#begin('~/.config/nvim/my-plugins/')
Plug 'http://github.com/tpope/vim-surround' " Surrounding ysw)
Plug 'https://github.com/preservim/nerdtree' " NerdTree
Plug 'https://github.com/tpope/vim-commentary' " For Commenting gcc & gc
Plug 'https://github.com/vim-airline/vim-airline' " Status bar
Plug 'vim-airline/vim-airline-themes'
Plug 'https://github.com/lifepillar/pgsql.vim' " PSQL Pluging needs :SQLSetType pgsql.vim
Plug 'https://github.com/ap/vim-css-color' " CSS Color Preview
Plug 'https://github.com/rafi/awesome-vim-colorschemes' " Retro Scheme
Plug 'https://github.com/ryanoasis/vim-devicons' " Developer Iconsinit.
Plug 'https://github.com/tc50cal/vim-terminal' " Vim Terminal
Plug 'https://github.com/preservim/tagbar' " Tagbar for code navigation
"Plug 'https://github.com/neoclide/coc.nvim'  " Auto Completion
Plug 'https://github.com/github/copilot.vim.git' " Copilot1
Plug 'https://github.com/andviro/flake8-vim.git' " Flake8
Plug 'ambv/black' " Black
Plug 'mickael-menu/zk-nvim' " Zettelkasten
Plug 'eslint/eslint' "eslint
Plug 'sbdchd/neoformat' " Neoformat
Plug 'neomake/neomake'
Plug 'neovim/nvim-lspconfig' " lsp plug languages
Plug 'nvim-lua/lsp-status.nvim'
Plug 'hrsh7th/nvim-compe'
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-cmdline'
" For vsnip users.
Plug 'hrsh7th/cmp-vsnip'
Plug 'hrsh7th/vim-vsnip'
" For luasnip users.
Plug 'L3MON4D3/LuaSnip'
Plug 'saadparwaiz1/cmp_luasnip'
Plug 'SirVer/ultisnips'
Plug 'quangnguyen30192/cmp-nvim-ultisnips'
Plug 'dcampos/nvim-snippy'
" Plug 'dcampos/cmp-snip'
Plug 'williamboman/nvim-lsp-installer'
Plug 'f-person/git-blame.nvim'
Plug 'dyng/ctrlsf.vim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-file-browser.nvim'
Plug 'folke/trouble.nvim'
Plug 'adoyle-h/ad-telescope-extensions.nvim'
Plug 'junegunn/fzf.vim'
Plug 'junegunn/fzf.vim'
Plug 'jose-elias-alvarez/null-ls.nvim'
Plug 'othree/html5.vim'
Plug 'mustache/vim-mustache-handlebars',
Plug 'pangloss/vim-javascript',
" Plug 'sheerun/vim-polyglot'

"Emmet 
Plug 'mattn/emmet-vim'

" React snippets
Plug 'SirVer/ultisnips'
Plug 'mlaursen/vim-react-snippets'

"Bufferline
Plug 'nvim-tree/nvim-web-devicons' " Recommended (for coloured icons)
Plug 'akinsho/bufferline.nvim', { 'tag': '*' }

Plug 'nvim-treesitter/nvim-treesitter',
Plug 'nvim-treesitter/nvim-treesitter-textobjects'
Plug 'romgrk/nvim-treesitter-context'
Plug 'nvim-telescope/telescope-live-grep-args.nvim'
Plug 'folke/which-key.nvim'
Plug 'ThePrimeagen/harpoon'
Plug 'christoomey/vim-tmux-navigator'
" Plug 'xiyaowong/transparent.nvim'
Plug 'gen740/SmoothCursor.nvim' 
Plug 'nvim-lua/plenary.nvim'
Plug 'jackMort/ChatGPT.nvim'
Plug 'MunifTanjim/nui.nvim'
Plug 'dotsilas/darcubox-nvim'
Plug 'OmniSharp/omnisharp-vim'
Plug 'rebelot/kanagawa.nvim'
Plug 'olimorris/onedarkpro.nvim'

Plug 'tpope/vim-dadbod'
Plug 'kristijanhusak/vim-dadbod-completion'
Plug 'kristijanhusak/vim-dadbod-ui'
Plug 'nvim-neorg/neorg'
Plug 'catppuccin/nvim', { 'as': 'catppuccin' }
Plug 'nvim-pack/nvim-spectre'
call plug#end()

source ~/.config/nvim/db.config.vim

let g:transparent_groups = extend(get(g:, 'transparent_groups', []), ['Pmenu', 'Float', 'NormalFloat'])
" ctrlp show hidden files
let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files -co --exclude-standard']
let g:ctrlp_show_hidden = 1

:set completeopt-=preview " For No Preview

" " Enable Coc on normal mode
" nmap <silent><leader>g <Plug>(coc-cmd)

" Set keybinds 
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
autocmd ColorScheme * highlight Normal ctermbg=NONE guibg=NONE
" colorscheme onedark
" colorscheme darcubox
" colorscheme dracula
highlight Pmenu guibg=NONE

inoremap <expr> <Tab> pumvisible() ? coc#_select_confirm() : "<Tab>"
set fillchars+=eob:\ " remove ~ from empty lines:
set wildmenu

" NerdTree config:
let g:NERDTreeShowHidden=1
let g:NERDTreeWinPos = "right"

" new buffer 
nnoremap <C-n> :let g:temp = ''<CR>
nnoremap <C-n>b :enew<CR>
nnoremap <C-n>v :vnew<CR>
" Telescope command line:
" Find files using Telescope command-line sugar.
nnoremap <C-p> <cmd>Telescope find_files hidden=true<cr>
nnoremap <C-u> :Telescope buffers<CR>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>
nnoremap <C-b> :Telescope file_browser cwd=<C-R>=expand("%:p:h")<CR><CR>
tnoremap <ESC> <C-\><C-n>

" Window manager config
nnoremap <C-t> :tabnew<CR>
nnoremap <C-tab> :tabnext<CR>
nnoremap <C-S-w> :bd<CR>
map <C-s><C-w> :w<bar>bd<CR>
map <leader>n :bnext<cr>
map <leader>p :bprevious<cr>
map <leader>d :bdelete<cr>

function! CreateFile()
  let filename = input("Enter filename: ")
  execute "e " . expand("%:p:h") . "/" . filename
endfunction

" Transform buffers to tabs
nnoremap <C-m> :tab sball<CR>

" Convert the current colorscheme into an fzf configuration line
" let g:fzf_colors =
" \ { 'fg':         ['fg', 'Normal'],
"   \ 'bg':         ['bg', 'Normal'],
"   \ 'preview-bg': ['bg', 'NormalFloat'],
"   \ 'hl':         ['fg', 'Comment'],
"   \ 'fg+':        ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
"   \ 'bg+':        ['bg', 'CursorLine', 'CursorColumn'],
"   \ 'hl+':        ['fg', 'Statement'],
"   \ 'info':       ['fg', 'PreProc'],
"   \ 'border':     ['fg', 'Ignore'],
"   \ 'prompt':     ['fg', 'Conditional'],
"   \ 'pointer':    ['fg', 'Exception'],
"   \ 'marker':     ['fg', 'Keyword'],
"   \ 'spinner':    ['fg', 'Label'],
"   \ 'header':     ['fg', 'Comment'] }

source ~/.config/nvim/setup.lua

set switchbuf+=usetab
set tabpagemax=9999




" Set search result border
highlight Search gui=NONE guibg=NONE guifg=NONE cterm=NONE ctermbg=NONE ctermfg=NONE
highlight Search gui=reverse cterm=reverse
highlight Search gui=undercurl guisp=white cterm=undercurl ctermfg=white

" Set opacity for search results

" highlight the visual selection after pressing enter.
xnoremap <silent> <cr> "*y:silent! let searchTerm = '\V'.substitute(escape(@*, '\/'), "\n", '\\n', "g") <bar> let @/ = searchTerm <bar> echo '/'.@/ <bar> call histadd("search", searchTerm) <bar> set hls<cr>

" Automatically select word under cursor
set updatetime=10

function! HighlightWordUnderCursor()
    if getline(".")[col(".")-1] !~# '[[:punct:][:blank:]]' 
        exec 'match' 'Search' '/\V\<'.expand('<cword>').'\>/' 
    else 
        match none 
    endif
endfunction

autocmd! CursorHold,CursorHoldI * call HighlightWordUnderCursor()
nnoremap <silent> ga <cmd>lua vim.lsp.buf.code_action()<CR>
nnoremap <silent> <leader>t :TroubleToggle<CR>
nnoremap <leader>z :vsplit \| terminal<CR>
nnoremap <leader>xx <cmd>TroubleToggle<cr>
nnoremap <leader>xw <cmd>TroubleToggle workspace_diagnostics<cr>
nnoremap <leader>xd <cmd>TroubleToggle document_diagnostics<cr>
nnoremap <leader>xq <cmd>TroubleToggle quickfix<cr>
nnoremap <leader>xl <cmd>TroubleToggle loclist<cr>
nnoremap <silent> <leader>h  <cmd>WhichKey<cr>
nnoremap <leader>w :set wrap!<CR>
nnoremap <S-f> <C-u>
nnoremap <S-j> <C-d>
" nnoremap <silent> <leader>fs <cmd>lua require("telescope").extensions.live_grep_args.live_grep_args()<CR>
nnoremap <silent> <leader>db <cmd>DBUIToggle<CR>


nnoremap <leader>c :ChatGPT<CR>

" air-line
let g:airline_powerline_fonts = 1

if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif

" unicode symbols
let g:airline_left_sep = '»'
let g:airline_left_sep = '▶'
let g:airline_right_sep = '«'
let g:airline_right_sep = '◀'
let g:airline_symbols.linenr = '␊'
let g:airline_symbols.linenr = '␤'
let g:airline_symbols.linenr = '¶'
let g:airline_symbols.branch = '⎇'
let g:airline_symbols.paste = 'ρ'
let g:airline_symbols.paste = 'Þ'
let g:airline_symbols.paste = '∥'
let g:airline_symbols.whitespace = 'Ξ'

" airline symbols
let g:airline_left_sep = ''
let g:airline_left_alt_sep = ''
let g:airline_right_sep = ''
let g:airline_right_alt_sep = ''
let g:airline_symbols.branch = ''
let g:airline_symbols.readonly = ''
let g:airline_symbols.linenr = ''
let g:airline_theme='deus'


" Toggle fullscreen mode
nnoremap <silent> <Leader>ff :call ToggleFullscreen()<CR>

let g:fullscreen_state = 0

function! ToggleFullscreen()
    if g:fullscreen_state == 0
        " Save current window state
        let g:fullscreen_win_state = winrestcmd()
        " Maximize current window
        wincmd _
        wincmd |
        let g:fullscreen_state = 1
    else
        " Restore previous window state
        execute g:fullscreen_win_state
        let g:fullscreen_state = 0
    endif
endfunction

let g:OmniSharp_server_stdio = 1

highlight SignColumn ctermbg=NONE guibg=NONE
  autocmd FileType sql,mysql,plsql lua require('cmp').setup.buffer({ sources = {{ name = 'vim-dadbod-completion' }} })

