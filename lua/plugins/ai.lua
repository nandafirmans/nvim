return {

  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = { enabled = false },
        panel = { enabled = false },
      })
    end,
  },

  {
    "zbirenbaum/copilot-cmp",
    dependencies = { "copilot.lua" },
    config = function()
      require("copilot_cmp").setup()
    end
  },

  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim" },
    },
    keys = {
      {
        "<leader>cco",
        mode = { "v", "n" },
        function()
          require("CopilotChat").open()
        end,
        desc = "CopilotChat - Open chat",
      },
      {
        "<leader>ccr",
        mode = { "v", "n" },
        function()
          require("CopilotChat").reset()
        end,
        desc = "CopilotChat - Reset",
      },
      {
        "<leader>ccq",
        mode = { "v", "n" },
        function()
          local input = vim.fn.input("Quick Chat: ")
          if input ~= "" then
            local selection
            if vim.fn.visualmode() ~= '' then
              selection = require("CopilotChat.select").visual
            else
              selection = require("CopilotChat.select").buffer
            end
            require("CopilotChat").ask(input, {
              selection = selection
            })
          end
        end,
        desc = "CopilotChat - Quick chat",
      },
      {
        "<leader>ccc",
        mode = { "n" },
        function()
          local input = vim.fn.input("Chat: ")
          require("CopilotChat").ask(input, {
            context = { 'buffer', 'files', 'registers:+' }
          })
        end
      },
      {
        "<leader>cch",
        mode = { "v", "n" },
        function()
          local actions = require("CopilotChat.actions")
          require("CopilotChat.integrations.telescope").pick(actions.help_actions())
        end,
        desc = "CopilotChat - Help actions",
      },
      {
        "<leader>ccp",
        mode = { "v", "n" },
        function()
          local actions = require("CopilotChat.actions")
          local selection
          if vim.fn.visualmode() ~= '' then
            selection = require("CopilotChat.select").visual
          else
            selection = require("CopilotChat.select").buffer
          end
          require("CopilotChat.integrations.telescope").pick(actions.prompt_actions({
            selection = selection
          }))
        end,
        desc = "CopilotChat - Prompt actions",
      },
    },
    config = function()
      require("CopilotChat").setup({
        model = "claude-sonnet-4",
        window = {
          layout = 'vertical',
          width = 0.3,
          height = 0.8,
          relative = 'editor',
          border = 'single',
          row = nil,
          col = nil,
          title = 'Copilot Chat',
          footer = nil,
          zindex = 1,
        },
      })
      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = 'copilot-*',
        callback = function()
          vim.opt_local.relativenumber = true

          -- C-p to print last response
          vim.keymap.set('n', '<C-p>', function()
            print(require("CopilotChat").response())
          end, { buffer = true, remap = true })
        end
      })
    end,
  },
  {
    "folke/sidekick.nvim",
    opts = {
      cli = {
        mux = {
          enabled = true,
          backend = "tmux",
        },
      },
      nes = {
        enabled = false,
      }
    },
    keys = {
      {
        "<leader>as",
        function() require("sidekick.cli").select({ filter = { installed = true } }) end,
        desc = "Select CLI",
      },
      {
        "<leader>at",
        function() require("sidekick.cli").send({ msg = "{this}", filter = { installed = true } }) end,
        mode = { "x", "n" },
        desc = "Send This",
      },
      {
        "<leader>av",
        function() require("sidekick.cli").send({ msg = "{selection}", filter = { installed = true } }) end,
        mode = { "x" },
        desc = "Send Visual Selection",
      },
      {
        "<leader>ap",
        function() require("sidekick.cli").prompt() end,
        mode = { "n", "x" },
        desc = "Sidekick Select Prompt",
      },
      {
        "<leader>ax",
        function() require("sidekick.cli").toggle({ name = "copilot", focus = true }) end,
        mode = { "n", "x", "t" },
        desc = "Sidekick Toggle Opencode",
      },
    },
  },
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "echasnovski/mini.pick",         -- for file_selector provider mini.pick
      "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
      "hrsh7th/nvim-cmp",              -- autocompletion for avante commands and mentions
      "ibhagwan/fzf-lua",              -- for file_selector provider fzf
      "stevearc/dressing.nvim",        -- for input provider dressing
      "folke/snacks.nvim",             -- for input provider snacks
      "nvim-tree/nvim-web-devicons",   -- or echasnovski/mini.icons
      "zbirenbaum/copilot.lua",        -- for providers='copilot'
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
    opts = {
      provider = 'copilot',
      auto_suggestions_provider = "copilot",
      providers = {
        copilot = {
          model = "claude-sonnet-4",
        },
      },
    },
    build = (function()
      if jit.os == "Windows" then
        return "pwsh -NoProfile Build.ps1"
      else
        return "make"
      end
    end)(),
  },
  {
    'NickvanDyke/opencode.nvim',
    dependencies = { 'folke/snacks.nvim', },
    opts = {
      terminal = {
        auto_insert = true,
        auto_close = true,
        win = {
          position = "float",
          enter = true,
        },
        env = {
          OPENCODE_THEME = "system",
        },
      },
    },
    keys = {
      { '<leader>ot', function() require('opencode').toggle() end,                           desc = 'Toggle embedded opencode', },
      { '<leader>oa', function() require('opencode').ask('@cursor: ') end,                   desc = 'Ask opencode',                 mode = 'n', },
      { '<leader>oa', function() require('opencode').ask('@selection: ') end,                desc = 'Ask opencode about selection', mode = 'v', },
      { '<leader>op', function() require('opencode').select_prompt() end,                    desc = 'Select prompt',                mode = { 'n', 'v', }, },
      { '<leader>on', function() require('opencode').command('session_new') end,             desc = 'New session', },
      { '<leader>oy', function() require('opencode').command('messages_copy') end,           desc = 'Copy last message', },
      { '<S-C-u>',    function() require('opencode').command('messages_half_page_up') end,   desc = 'Scroll messages up', },
      { '<S-C-d>',    function() require('opencode').command('messages_half_page_down') end, desc = 'Scroll messages down', },
    },
  }
}
