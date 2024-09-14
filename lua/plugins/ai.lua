return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
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
    opts = {
      -- default window options
      window = {
        layout = 'float',       -- 'vertical', 'horizontal', 'float'
        -- Options below only apply to floating windows
        relative = 'editor',    -- 'editor', 'win', 'cursor', 'mouse'
        border = 'single',      -- 'none', single', 'double', 'rounded', 'solid', 'shadow'
        width = 0.8,            -- fractional width of parent
        height = 0.6,           -- fractional height of parent
        row = nil,              -- row position of the window, default is centered
        col = nil,              -- column position of the window, default is centered
        title = 'Copilot Chat', -- title of chat window
        -- footer = nil,           -- footer of chat window
        zindex = 1,             -- determines if window is on top or below other floating windows
      },
    }
  },
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false, -- set this if you want to always pull the latest change
    opts = {
      provider = 'copilot'
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      "zbirenbaum/copilot.lua",      -- for providers='copilot'
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
            -- use_absolute_path = true,
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
  }
}
