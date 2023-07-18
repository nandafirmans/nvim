return {

  {
    "github/copilot.vim",
    lazy = false,
    config = function()
      vim.api.nvim_set_keymap("i", "<A-j>", 'copilot#Accept("<CR>")', { silent = true, expr = true })
      vim.g.copilot_no_tab_map = true
      vim.g.copilot_filetypes = {
        ["*"] = false,
        ["javascript"] = true,
        ["typescript"] = true,
        ["css"] = true,
        ["scss"] = true,
        ["less"] = true,
        ["html"] = true,
        ["lua"] = true,
        ["rust"] = false,
        ["c"] = false,
        ["c#"] = false,
        ["c++"] = false,
        ["go"] = true,
        ["python"] = false,
      }
    end
  },

  -- {
  --   "zbirenbaum/copilot.lua",
  --   cmd = "Copilot",
  --   event = "InsertEnter",
  --   config = function()
  --     require("copilot").setup({
  --       suggestion = { enabled = false },
  --       panel = { enabled = false },
  --     })
  --   end,
  -- },
  --
  -- {
  --   "zbirenbaum/copilot-cmp",
  --   dependencies = { "copilot.lua" },
  --   config = function()
  --     require("copilot_cmp").setup({
  --       formatters = {
  --         label = require("copilot_cmp.format").format_label_text,
  --         insert_text = require("copilot_cmp.format").format_insert_text,
  --         preview = require("copilot_cmp.format").deindent,
  --       },
  --     })
  --   end
  -- },

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
    config = function()
      -- local has_words_before = function()
      --   if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then return false end
      --   local line, col = unpack(vim.api.nvim_win_get_cursor(0))
      --   return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
      -- end

      -- nvim-cmp setup
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      -- LuaSnip
      require("luasnip.loaders.from_vscode").lazy_load()
      luasnip.filetype_extend("javascript", { "javascriptreact" })
      luasnip.filetype_extend("javascript", { "html" })

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        formatting = {
          format = require('lspkind').cmp_format({
            mode = 'symbol',
            maxwidth = 50,
          }),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-d>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            -- if cmp.visible() and has_words_before() then
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = {
          -- { name = "copilot",  group_index = 2 },
          { name = "nvim_lsp", group_index = 2 },
          { name = "luasnip",  group_index = 2 },
          { name = "path",     group_index = 2 },
        },
      })
    end
  },

  {
    "dsznajder/vscode-es7-javascript-react-snippets",
    build = "yarn install --frozen-lockfile && yarn compile",
  },
}
