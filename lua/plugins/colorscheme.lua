return {
  { "navarasu/onedark.nvim" },
  { "dracula/vim" },
  { "folke/tokyonight.nvim" },
  { "catppuccin/nvim" },
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
        devicons = true, -- highlight the icons of `nvim-web-devicons`
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
}
