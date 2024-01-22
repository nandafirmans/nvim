return {
  {
    -- LSP Configuration & Plugins
    "neovim/nvim-lspconfig",
  },

  -- VSCode like picktogram
  { "onsails/lspkind.nvim" },

  -- {
  --   "jmederosalvarado/roslyn.nvim",
  --   config = function()
  --     local lsp_util = require("plugins.lsp.util")
  --     local on_attach = lsp_util.on_attach;
  --     local capabilities = lsp_util.capabilities;
  --     require("roslyn").setup({
  --       dotnet_cmd = "dotnet",
  --       roslyn_version = "4.8.0-3.23475.7",
  --       on_attach = on_attach,
  --       capabilities = capabilities,
  --     })
  --   end
  -- },

  {
    -- Automatically install LSPs to stdpath for neovim
    "williamboman/mason.nvim",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      'Hoffs/omnisharp-extended-lsp.nvim',
    },
    config = function()
      require("mason").setup()
      local lsp_util = require("plugins.lsp.util")
      local servers = lsp_util.servers;
      local on_attach = lsp_util.on_attach;
      local capabilities = lsp_util.capabilities;
      local mason_lspconfig = require("mason-lspconfig")

      mason_lspconfig.setup({
        ensure_installed = vim.tbl_keys(servers),
      })

      mason_lspconfig.setup_handlers({
        function(server_name)
          require("lspconfig")[server_name].setup({
            capabilities = capabilities,
            on_attach = on_attach,
            settings = servers[server_name],
          })
        end,
      })

      -- Disable TS Formatting
      require("lspconfig").tsserver.setup({
        capabilities = capabilities,
        on_attach = function(client)
          client.server_capabilities.documentFormattingProvider = false
        end,
      })

      local pid = vim.fn.getpid()
      -- local omnisharp_bin = "C:\\Users\\nanda\\AppData\\Local\\nvim-data\\mason\\bin\\omnisharp.cmd"
      local omnisharp_bin = "/home/nandafirmans/.local/share/nvim/mason/bin/omnisharp";

      require("lspconfig").omnisharp.setup({
        handlers = {
          ["textDocument/definition"] = require('omnisharp_extended').handler,
        },
        cmd = { omnisharp_bin, '--languageserver', '--hostPID', tostring(pid) },
      })

      -- Eslint Fix All
      -- TODO: auto fix all eslint on save
      vim.keymap.set("n", "<leader>efa", "<Cmd>EslintFixAll<CR>")
    end
  },

  -- null-ls is used for formatters/diagnostics not provided by the language server
  {
    "jose-elias-alvarez/null-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local lsp_util = require("plugins.lsp.util")
      local null_ls = require("null-ls")
      null_ls.setup({
        sources = {
          null_ls.builtins.formatting.prettierd,
          null_ls.builtins.formatting.sqlfluff,
          null_ls.builtins.formatting.gofmt,
          null_ls.builtins.formatting.goimports,
          null_ls.builtins.formatting.goimports_reviser,
          null_ls.builtins.formatting.golines,
          -- null_ls.builtins.formatting.csharpier
        },
        on_attach = lsp_util.on_attach
      })
    end
  },

  {
    -- Additional lua configuration, makes nvim stuff amazing
    "folke/neodev.nvim",
    config = function()
      require("neodev").setup()
    end
  },

  -- LSP File Operations
  {
    "antosha417/nvim-lsp-file-operations",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-tree.lua",
    },
    config = function()
      require("lsp-file-operations").setup()
    end
  },

  -- Flutter
  {
    'akinsho/flutter-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local lsp_util = require("plugins.lsp.util")
      require("flutter-tools").setup({
        lsp = {
          capabilities = lsp_util.capabilities,
          on_attach = lsp_util.on_attach,
        }
      })
    end
  },

  {
    "glepnir/lspsaga.nvim",
    lazy = false,
    branch = "main",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      symbol_in_winbar = {
        enable = false,
        hide_keyword = false,
        show_file = true,
        folder_level = 1,
        respect_root = false,
        color_mode = true,
      },
    },
    config = function(_, opts)
      require("lspsaga").setup(opts)
    end,
    keys = {
      {
        "gh",
        "<cmd>Lspsaga finder<CR>",
        mode = "n"
      },
      {
        "<leader>ca",
        "<cmd>Lspsaga code_action<CR>",
        mode = { "n", "v" },
        desc = "[C]ode [A]ction"
      },
      {
        "<leader>rn",
        "<cmd>Lspsaga rename<CR>",
        mode = "n",
        desc = "[R]e[N]ame"
      },
      {
        "gp",
        "<cmd>Lspsaga peek_definition<CR>",
        mode = "n",
        desc = "Peek Definition"
      },
      {
        "gd",
        "<cmd>Lspsaga goto_definition<CR>",
        mode = "n",
        desc = "[G]o to [D]efinition"
      },
      {
        "<leader>sl",
        "<cmd>Lspsaga show_line_diagnostics<CR>",
        mode = "n",
      },
      {
        "<leader>sc",
        "<cmd>Lspsaga show_cursor_diagnostics<CR>",
        mode = "n",
      },
      {
        "<leader>sb",
        "<cmd>Lspsaga show_buf_diagnostics<CR>",
        mode = "n",
      },
      {
        "[e",
        "<cmd>Lspsaga diagnostic_jump_prev<CR>",
        mode = "n",
      },
      {
        "]e",
        "<cmd>Lspsaga diagnostic_jump_next<CR>",
        mode = "n",
      },
      {
        "[E",
        function()
          require("lspsaga.diagnostic"):goto_prev({ severity = vim.diagnostic.severity.ERROR })
        end,
        mode = "n",
      },
      {
        "]E",
        function()
          require("lspsaga.diagnostic"):goto_next({ severity = vim.diagnostic.severity.ERROR })
        end,
        mode = "n",
      },
      {
        "<leader>o",
        "<cmd>Lspsaga outline<CR>",
        mode = "n",
      },
      {
        "<Leader>ci",
        "<cmd>Lspsaga incoming_calls<CR>",
        mode = "n",
      },
      {
        "<Leader>co",
        "<cmd>Lspsaga outgoing_calls<CR>",
        mode = "n",
      },
      {
        "K",
        "<cmd>Lspsaga hover_doc<CR>",
        mode = "n",
      },
      -- {
      --   "<A-T>",
      --   "<cmd>Lspsaga term_toggle<CR>",
      --   mode = { "n", "t" },
      -- },
    }
  },
}
