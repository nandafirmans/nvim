return {
  -- Fuzzy Finder (files, lsp, etc)
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim", },
    config = function()
      require("telescope").setup({
        defaults = {
          mappings = {
            i = {
              ["<C-u>"] = false,
              ["<C-d>"] = false,
            },
          },
          -- path_display = {
          --   truncate = 3
          -- }
          path_display = function(opts, path)
            local tail = require("telescope.utils").path_tail(path)
            local formated_path = require("telescope.utils").transform_path({ path_display = { truncate = 3 } }, path)
            formated_path = formated_path:gsub("/" .. tail, "")
            return string.format("%s - %s", tail, formated_path), { { { 1, #tail }, "Constant" } }
          end,
        },
        pickers = {
          colorscheme = {
            theme = "dropdown",
            enable_preview = true,
            initial_mode = "normal",
          },
          buffers = {
            -- theme = "dropdown",
            previewer = false,
            initial_mode = "normal",
            -- path_display = {
            --   shorten = 2,
            --   truncate = 3,
            -- }
          },
        },
        extensions = {
          file_browser = {
            -- theme = "dropdown",
            initial_mode = "normal",
            hijack_netrw = true,
            previewer = false,
            path_display = {
              truncate = 3
            },
          },
        },
      })

      require("telescope").load_extension("fzf")
      require("telescope").load_extension("file_browser")
      require("telescope").load_extension("flutter")
      require("telescope").load_extension("session-lens")
    end,
    keys = {
      {
        "<leader>?",
        function() require("telescope.builtin").oldfiles(); end,
        desc = "[?] Find recently opened files"
      },
      {
        "<leader><space>",
        function() require("telescope.builtin").buffers(); end,
        desc = "[ ] Find existing buffers"
      },
      {
        "<leader>f/",
        function()
          require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
            winblend = 10,
            previewer = false,
          }));
        end,
        desc = "[/] Fuzzily search in current buffer]"
      },
      {
        "gr",
        function() require("telescope.builtin").lsp_references(); end,
        desc =
        "[ ] LSP References"
      },
      {
        "<leader>ds",
        function() require("telescope.builtin").lsp_document_symbols(); end,
        desc =
        "[D]ocument [S]ymbols"
      },
      {
        "<leader>ws",
        function() require("telescope.builtin").lsp_dynamic_workspace_symbols(); end,
        desc =
        "[W]orkspace [S]ymbols"
      },
      {
        "<leader>fr",
        function() require("telescope.builtin").resume(); end,
        desc =
        "[ ] Resume Last Find"
      },
      {
        "<leader>ff",
        function() require("telescope.builtin").find_files(); end,
        desc =
        "[F]ind [F]iles"
      },
      {
        "<leader>fh",
        function() require("telescope.builtin").help_tags(); end,
        desc =
        "[F]ind [H]elp"
      },
      {
        "<leader>fw",
        function() require("telescope.builtin").grep_string(); end,
        desc =
        "[F]ind current [W]ord"
      },
      {
        "<leader>fg",
        function() require("telescope.builtin").live_grep(); end,
        desc =
        "[F]ind by [G]rep"
      },
      {
        "<leader>fd",
        function() require("telescope.builtin").diagnostics(); end,
        desc =
        "[F]ind [D]iagnostics"
      },
      {
        "<leader>fc",
        function() require("telescope.builtin").commands(); end,
        desc =
        "[F]ind [C]ommands"
      },
      {
        "<leader>fs",
        function() require("telescope.builtin").colorscheme(); end,
        desc =
        "[F]ind color[S]chemes"
      },
      {
        "<leader>fk",
        function() require("telescope.builtin").keymaps(); end,
        desc =
        "[F]ind [K]eymaps"
      },
      {
        "<leader>ft",
        "<Cmd>TodoTelescope<CR>",
        desc =
        "[F]ind [T]odo"
      },
      {
        "<leader>fb",
        "<Cmd>Telescope file_browser path=%:p:h select_buffer=true<CR>",
        desc =
        "[F]ile [B]rowser"
      },
    }
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

  -- {
  --   'ThePrimeagen/harpoon',
  --   dependencies = { 'nvim-lua/plenary.nvim' },
  --   lazy = false,
  --   keys = {
  --     {
  --       "<leader>hh",
  --       function()
  --         require("harpoon.ui").toggle_quick_menu()
  --       end,
  --       mode = "n"
  --     },
  --     {
  --       "<leader>ha",
  --       function()
  --         require("harpoon.mark").add_file()
  --       end,
  --       mode = "n"
  --     },
  --     {
  --       "<leader>hx",
  --       function()
  --         require("harpoon.mark").clear_all()
  --       end,
  --       mode = "n"
  --     },
  --     {
  --       "<leader>hj",
  --       function()
  --         require("harpoon.ui").nav_next()
  --       end,
  --       mode = "n"
  --     },
  --     {
  --       "<leader>hk",
  --       function()
  --         require("harpoon.ui").nav_prev()
  --       end,
  --       mode = "n"
  --     }
  --   },
  --   config = function()
  --     require("harpoon").setup({
  --       menu = {
  --         width = 120,
  --       }
  --     })
  --   end
  -- }
}
