return {
  -- Fuzzy Finder (files, lsp, etc)
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "isak102/telescope-git-file-history.nvim",
        dependencies = {
          "nvim-lua/plenary.nvim",
          "tpope/vim-fugitive"
        }
      }
    },
    config = function()
      require("telescope").setup({
        defaults = {
          file_ignore_patterns = { '%__virtual.cs$', '%__virtual.html$' },
          vimgrep_arguments = {
            'rg',
            '--color=never',
            '--no-heading',
            '--with-filename',
            '--line-number',
            '--column',
            '--smart-case',
            '--multiline',
            '--multiline-dotall'
          },
          path_display = function(_, path)
            local tail = require("telescope.utils").path_tail(path)
            local formated_path = require("telescope.utils").transform_path({ path_display = { truncate = 3 } }, path)
            formated_path = formated_path:gsub(tail, "")
            if formated_path == "" then
              formated_path = "/"
            end
            return string.format("%s │ %s", tail, formated_path), { { { 1, #tail }, "Constant" } }
          end,
          highlight = true,
          hl_result_eol = true,
        },
        pickers = {
          colorscheme = {
            theme = "dropdown",
            enable_preview = true,
            initial_mode = "normal",
          },
          live_grep = {
            attach_mappings = function(_, map)
              map("n", "/", function()
                local action_state = require("telescope.actions.state")
                local search_text = action_state.get_current_line()
                if search_text and search_text ~= "" then
                  vim.cmd([[/]] .. search_text);
                end
              end)
              return true
            end,
          },
          buffers = {
            layout_config = {
              width = 0.5,
            },
            theme = "dropdown",
            sort_lastused = true,
            ignore_current_buffer = true,
            previewer = false,
            initial_mode = "normal",
          },
        },
        extensions = {
          file_browser = {
            initial_mode = "normal",
            hijack_netrw = true,
            previewer = true,
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
      require("telescope").load_extension("git_file_history")
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
        function() require("telescope").extensions.git_file_history.git_file_history(); end,
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

}
