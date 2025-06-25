return {
  {
    -- LSP Configuration & Plugins
    "neovim/nvim-lspconfig",
    lazy = false,
  },

  -- VSCode like picktogram
  { "onsails/lspkind.nvim" },

  { "mason-org/mason-lspconfig.nvim", version = "^1.0.0" },
  {
    "nvim-java/nvim-java",
    config = function()
      local lsp_util = require("plugins.lsp.util")
      local on_attach = lsp_util.on_attach;
      local capabilities = lsp_util.capabilities;
      require("java").setup()
      require("lspconfig").jdtls.setup({
        capabilities = capabilities,
        on_attach = on_attach,
      })
    end
  },
  {
    -- Automatically install LSPs to stdpath for neovim
    "mason-org/mason.nvim",
    version = "^1.0.0",
    dependencies = {
      "mason-org/mason-lspconfig.nvim",
      "pmizio/typescript-tools.nvim",
      "nvim-lua/plenary.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      require("mason").setup({
        registries = {
          "github:mason-org/mason-registry",
          "github:Crashdummyy/mason-registry",
        }
      })
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
          if (server_name == "ts_ls") then
            return
          end

          require("lspconfig")[server_name].setup({
            capabilities = capabilities,
            on_attach = on_attach,
            settings = servers[server_name],
          })
        end,
      })

      require("lspconfig").ts_ls.setup({
        capabilities = capabilities,
        on_attach = function(client)
          client.server_capabilities.documentFormattingProvider = false
        end
      })

      -- Eslint Fix All
      vim.keymap.set("n", "<leader>efa", "<Cmd>EslintFixAll<CR>")
    end
  },

  -- null-ls is used for formatters/diagnostics not provided by the language server
  {
    "nvimtools/none-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local lsp_util = require("plugins.lsp.util")
      local null_ls = require("null-ls")
      null_ls.setup({
        sources = {
          null_ls.builtins.formatting.prettier,
          null_ls.builtins.formatting.sqlfluff,
          null_ls.builtins.formatting.gofmt,
          null_ls.builtins.formatting.goimports,
          null_ls.builtins.formatting.goimports_reviser,
          null_ls.builtins.formatting.golines,
          null_ls.builtins.formatting.csharpier
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
      definition = {
        width = 0.8,
        height = 0.9,
      },
    },
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
      {
        "<A-T>",
        "<cmd>Lspsaga term_toggle<CR>",
        mode = { "n", "t" },
      },
    }
  },


  {
    "jlcrochet/vim-razor",
    config = function()
      vim.cmd [[
        au BufRead,BufNewFile *.cshtml set filetype=razor
      ]]
    end
  },

  {
    "seblyng/roslyn.nvim",
    dependencies = {
      {
        "tris203/rzls.nvim",
        config = function()
          local lsp_util = require("plugins.lsp.util")
          local capabilities = lsp_util.capabilities;
          local on_attach = lsp_util.on_attach;

          require('rzls').setup {
            on_attach = on_attach,
            capabilities = capabilities,
          }
        end,
      },
    },
    ft = { "razor", "cs" },
    config = function()
      local lsp_util = require("plugins.lsp.util")
      local capabilities = lsp_util.capabilities;
      local on_attach = lsp_util.on_attach;

      local rzls_path = vim.fn.expand("$MASON/packages/rzls/libexec")
      local cmd = {
        "roslyn",
        "--stdio",
        "--logLevel=Information",
        "--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.get_log_path()),
        "--razorSourceGenerator=" .. vim.fs.joinpath(rzls_path, "Microsoft.CodeAnalysis.Razor.Compiler.dll"),
        "--razorDesignTimePath=" .. vim.fs.joinpath(rzls_path, "Targets", "Microsoft.NET.Sdk.Razor.DesignTime.targets"),
        "--extension",
        vim.fs.joinpath(rzls_path, "RazorExtension", "Microsoft.VisualStudioCode.RazorExtension.dll"),
      }

      require("roslyn").setup({
        broad_search = true,
        filewatching = "auto",
      })

      vim.lsp.config("roslyn", {
        cmd = cmd,
        on_attach = on_attach,
        capabilities = capabilities,
        handlers = require("rzls.roslyn_handlers"),
        settings = {
          ["csharp|background_analysis"] = {
            ["background_analysis.dotnet_analyzer_diagnostics_scope"] = "fullSolution",
            ["background_analysis.dotnet_compiler_diagnostics_scope"] = "fullSolution"
          },
          ["csharp|symbol_search"] = {
            dotnet_search_reference_assemblies = true,
          },
          ["csharp|inlay_hints"] = {
            csharp_enable_inlay_hints_for_implicit_object_creation = true,
            csharp_enable_inlay_hints_for_implicit_variable_types = true,

            csharp_enable_inlay_hints_for_lambda_parameter_types = true,
            csharp_enable_inlay_hints_for_types = true,
            dotnet_enable_inlay_hints_for_indexer_parameters = true,
            dotnet_enable_inlay_hints_for_literal_parameters = true,
            dotnet_enable_inlay_hints_for_object_creation_parameters = true,
            dotnet_enable_inlay_hints_for_other_parameters = true,
            dotnet_enable_inlay_hints_for_parameters = true,
            dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
            dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
            dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
          },
          ["csharp|code_lens"] = {
            dotnet_enable_references_code_lens = true,
          },
        },
      })
      vim.lsp.enable("roslyn")
    end,
    init = function()
      vim.filetype.add {
        extension = {
          razor = 'razor',
          cshtml = 'razor',
        },
      }
    end,
  },
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    config = function()
      require("trouble").setup({
        modes = {
          diagnostics = {
            filter = function(items)
              return vim.tbl_filter(function(item)
                return not string.match(item.basename, [[%__virtual.cs$]])
              end, items)
            end,
          },
        },
      })
    end,
    keys = {
      {
        "<leader>xx",
        "<cmd>Trouble diagnostics toggle<cr>",
        desc = "Diagnostics (Trouble)",
      },
      {
        "<leader>xX",
        "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
        desc = "Buffer Diagnostics (Trouble)",
      },
      {
        "<leader>cs",
        "<cmd>Trouble symbols toggle focus=false<cr>",
        desc = "Symbols (Trouble)",
      },
      {
        "<leader>cl",
        "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
        desc = "LSP Definitions / references / ... (Trouble)",
      },
      {
        "<leader>xL",
        "<cmd>Trouble loclist toggle<cr>",
        desc = "Location List (Trouble)",
      },
      {
        "<leader>xQ",
        "<cmd>Trouble qflist toggle<cr>",
        desc = "Quickfix List (Trouble)",
      },
    },
  }
}
