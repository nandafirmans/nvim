return {
  { "dracula/vim",                      lazy = false,       priority = 1000 },
  { "catppuccin/nvim",                  lazy = false,       priority = 1000 },
  { "sainnhe/sonokai",                  lazy = false,       priority = 1000 },
  { "sickill/vim-monokai",              lazy = false,       priority = 1000 },
  { "edeneast/nightfox.nvim",           lazy = false,       priority = 1000 },
  { "Shatur/neovim-ayu",                lazy = false,       priority = 1000 },
  { "tomasr/molokai",                   lazy = false,       priority = 1000 },
  { "glepnir/oceanic-material",         lazy = false,       priority = 1000 },
  { "thedenisnikulin/vim-cyberpunk",    lazy = false,       priority = 1000 },
  { "dunstontc/vim-vscode-theme",       lazy = false,       priority = 1000 },
  { "adrian5/oceanic-next-vim",         lazy = false,       priority = 1000 },
  { "nlknguyen/papercolor-theme",       lazy = false,       priority = 1000 },
  { "nonetallt/vim-neon-dark",          lazy = false,       priority = 1000 },
  { "rebelot/kanagawa.nvim",            lazy = false,       priority = 1000 },
  { "sainnhe/edge",                     lazy = false,       priority = 1000 },
  { "sainnhe/gruvbox-material",         lazy = false,       priority = 1000 },
  { "luisiacc/gruvbox-baby",            lazy = false,       priority = 1000 },
  { "jacoborus/tender.vim",             lazy = false,       priority = 1000 },
  { 'nyoom-engineering/oxocarbon.nvim', lazy = false,       priority = 1000 },
  { 'AhmedAbdulrahman/aylin.vim',       lazy = false,       priority = 1000 },
  { 'pineapplegiant/spaceduck',         lazy = false,       priority = 1000 },
  { 'jaredgorski/spacecamp',            lazy = false,       priority = 1000 },
  { 'patstockwell/vim-monokai-tasty',   lazy = false,       priority = 1000 },
  { 'ray-x/aurora',                     lazy = false,       priority = 1000 },
  { 'rmehri01/onenord.nvim',            lazy = false,       priority = 1000 },
  { 'Mofiqul/vscode.nvim',              lazy = false,       priority = 1000 },
  { 'craftzdog/solarized-osaka.nvim',   lazy = false,       priority = 1000 },
  { "zootedb0t/citruszest.nvim",        lazy = false,       priority = 1000, },
  { 'projekt0n/github-nvim-theme',      lazy = false,       priority = 1000 },
  { 'xero/miasma.nvim',                 lazy = false,       priority = 1000 },
  { 'eldritch-theme/eldritch.nvim',     lazy = false,       priority = 1000 },
  { 'sainnhe/everforest',               lazy = false,       priority = 1000 },
  { 'tiagovla/tokyodark.nvim',          lazy = false,       priority = 1000 },
  { 'marko-cerovac/material.nvim',      lazy = false,       priority = 1000 },
  { "bluz71/vim-nightfly-colors",       name = "nightfly",  lazy = false,    priority = 1000 },
  { "bluz71/vim-moonfly-colors",        name = "moonfly",   lazy = false,    priority = 1000 },
  { 'rose-pine/neovim',                 name = 'rose-pine', lazy = false,    priority = 1000 },
  { 'srcery-colors/srcery-vim',         name = 'srcery',    lazy = false,    priority = 1000 },
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "darker",     -- Options: 'darker', 'warmer', 'cooler', 'deep', 'warm', 'light'
      transparent = false,  -- Enable transparent background
      term_colors = true,   -- Enable terminal colors
      ending_tildes = true, -- Show ending tildes
      highlights = {},      -- Override default highlights
    }
  },
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = true,
    }
  },
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = true,
    }
  },
  {
    "0xstepit/flow.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("flow").setup {
        transparent = true,       -- Set transparent background.
        fluo_color = "pink",      --  Fluo color: pink, yellow, orange, or green.
        mode = "normal",          -- Intensity of the palette: normal, bright, desaturate, or dark. Notice that dark is ugly!
        aggressive_spell = false, -- Display colors for spell check.
      }
    end
  },
  {
    "loctvl842/monokai-pro.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("monokai-pro").setup({
        terminal_colors = true,
        devicons = true,     -- highlight the icons of `nvim-web-devicons`
        italic_comments = true,
        filter = "spectrum", -- classic | octagon | pro | machine | ristretto | spectrum
      })
    end
  },
  {
    'uloco/bluloco.nvim',
    lazy = false,
    priority = 1000,
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
  {
    'AlexvZyl/nordic.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      require 'nordic'.load()
    end
  },
  {
    'maxmx03/fluoromachine.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      require('fluoromachine').setup({
        glow = false,
        -- theme = 'retrowave',
        -- theme = 'delta',
        theme = 'fluoromachine',
        --transparent = 'full'
      })
    end
  }
}
