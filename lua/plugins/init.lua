return {
  {
    -- LSP Configuration & Plugins
    "neovim/nvim-lspconfig",
    dependencies = {
      -- Automatically install LSPs to stdpath for neovim
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",

      -- Useful status updates for LSP
      "j-hui/fidget.nvim",

      -- Additional lua configuration, makes nvim stuff amazing
      "folke/neodev.nvim",
    },
  },

  {
    -- Autocompletion
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      -- Snippet
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
  },


  {
    "dsznajder/vscode-es7-javascript-react-snippets",
    build = "yarn install --frozen-lockfile && yarn compile",
  },

  -- VSCode like picktogram
  { "onsails/lspkind.nvim" },

  {
    -- Highlight, edit, and navigate code
    "nvim-treesitter/nvim-treesitter",
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    build = function()
      pcall(require("nvim-treesitter.install").update({ with_sync = true }))
    end,
  },

  {
    "jose-elias-alvarez/null-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  {
    "glepnir/lspsaga.nvim",
    branch = "main",
    dependencies = {
      { "nvim-tree/nvim-web-devicons" },
      --Please make sure you install markdown and markdown_inline parser
      { "nvim-treesitter/nvim-treesitter" },
    },
  },

  {
    "nvim-tree/nvim-tree.lua",
    tag = "nightly",                 -- optional, updated every week. (see issue #1193)
    dependencies = {
      "nvim-tree/nvim-web-devicons", -- optional, for file icons
    },
  },

  { "nvim-tree/nvim-web-devicons" },
  {
    "romgrk/barbar.nvim",
    dependencies = "nvim-web-devicons",
  },

  -- AutoSession & SessionLens
  { "rmagatti/auto-session" },
  {
    "rmagatti/session-lens",
    dependencies = {
      "rmagatti/auto-session",
      "nvim-telescope/telescope.nvim"
    },
  },

  -- Git Diffview
  {
    "sindrets/diffview.nvim",
    dependencies = "nvim-lua/plenary.nvim",
  },

  -- Auto close tag
  { "windwp/nvim-ts-autotag" },

  -- Auto pair char
  { "windwp/nvim-autopairs" },

  -- Multi Cursor
  {
    "mg979/vim-visual-multi",
    branch = "master"
  },

  -- Show hex color and rgb
  { "norcalli/nvim-colorizer.lua" },

  -- Flutter
  {
    'akinsho/flutter-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' }
  },

  -- ZenMode
  {
    "folke/zen-mode.nvim",
    config = function()
      require("zen-mode").setup {}
    end
  },

  -- Todo Highlight
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  -- FineCmdline
  {
    'VonHeikemen/fine-cmdline.nvim',
    dependencies = { 'MunifTanjim/nui.nvim' }
  },

  -- SearchBox
  {
    'VonHeikemen/searchbox.nvim',
    dependencies = { 'MunifTanjim/nui.nvim' }
  },

  -- VimIlluminate
  { "RRethy/vim-illuminate" },

  -- ToggleTerm
  { "akinsho/toggleterm.nvim" },

  -- Git related plugins
  { "tpope/vim-fugitive" },
  { "tpope/vim-rhubarb" },
  { "lewis6991/gitsigns.nvim" },

  -- Color scheme
  { "navarasu/onedark.nvim" },
  { "dracula/vim" },
  { "folke/tokyonight.nvim" },
  {
    "catppuccin/nvim",
    as = "catppuccin"
  },
  { "sainnhe/sonokai" },
  { "sickill/vim-monokai" },
  { "edeneast/nightfox.nvim" },
  { "ayu-theme/ayu-vim" },
  { "tomasr/molokai" },
  { "glepnir/oceanic-material" },
  { "thedenisnikulin/vim-cyberpunk" },
  { "dunstontc/vim-vscode-theme" },
  { "adrian5/oceanic-next-vim" },
  { "nlknguyen/papercolor-theme" },
  { "nonetallt/vim-neon-dark" },
  {
    "loctvl842/monokai-pro.nvim",
    config = function()
      require("monokai-pro").setup({
        terminal_colors = true,
        devicons = true,    -- highlight the icons of `nvim-web-devicons`
        italic_comments = true,
        filter = "octagon", -- classic | octagon | pro | machine | ristretto | spectrum
      })
    end
  },
  {
    'uloco/bluloco.nvim',
    dependencies = { 'rktjmp/lush.nvim' },
    config = function()
      require("bluloco").setup({
        style       = "auto", -- "auto" | "dark" | "light"
        transparent = false,
        italics     = true,
        terminal    = vim.fn.has("gui_running") == 1, -- bluoco colors are enabled in gui terminals per default.
        guicursor   = true,
      })
    end
  },
  { "nvim-lualine/lualine.nvim" },           -- Fancier statusline
  { "lukas-reineke/indent-blankline.nvim" }, -- Add indentation guides even on blank lines
  { "numToStr/Comment.nvim" },               -- "gc" to comment visual regions/lines
  { "tpope/vim-sleuth" },                    -- Detect tabstop and shiftwidth automatically

  -- Fuzzy Finder (files, lsp, etc)
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim", }
  },

  -- Fuzzy Finder Algorithm which requires local dependencies to be built. Only load if `make` is available
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    cond = vim.fn.executable("make") == 1
  },

  -- Telescope File Browser
  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim", },
  },
}
