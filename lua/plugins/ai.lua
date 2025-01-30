return {

  -- {
  --   "github/copilot.vim",
  --   lazy = false,
  --   config = function()
  --     vim.api.nvim_set_keymap("i", "<A-j>", 'copilot#Accept("<CR>")', { silent = true, expr = true })
  --     vim.g.copilot_no_tab_map = true
  --     vim.g.copilot_filetypes = {
  --       ["*"] = false,
  --       ["md"] = true,
  --       ["javascript"] = true,
  --       ["typescript"] = true,
  --       ["typescriptreact"] = true,
  --       ["css"] = true,
  --       ["scss"] = true,
  --       ["less"] = true,
  --       ["html"] = true,
  --       ["lua"] = true,
  --       ["rust"] = false,
  --       ["c"] = false,
  --       ["c#"] = false,
  --       ["c++"] = false,
  --       ["go"] = false,
  --       ["python"] = false,
  --     }
  --   end
  -- },

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
    -- branch = "canary",
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
      -- provider = 'copilot',
      provider = "ollama",
      vendors = {
        ollama = {
          __inherited_from = "openai",
          api_key_name = "",
          ask = "",
          endpoint = "http://127.0.0.1:11434/api",
          model = "qwen2.5-coder:7b",
          parse_curl_args = function(opts, code_opts)
            return {
              url = opts.endpoint .. "/chat",
              headers = {
                ["Accept"] = "application/json",
                ["Content-Type"] = "application/json",
              },
              body = {
                model = opts.model,
                options = {
                  num_ctx = 16384,
                },
                messages = require("avante.providers").copilot.parse_messages(code_opts), -- you can make your own message, but this is very advanced
                stream = true,
              },
            }
          end,
          parse_stream_data = function(data, handler_opts)
            local json_data = vim.fn.json_decode(data)
            if json_data and json_data.done then
              handler_opts.on_complete(nil) -- Properly terminate the stream
              return
            end
            if json_data and json_data.message and json_data.message.content then
              local content = json_data.message.content
              handler_opts.on_chunk(content)
            end
          end,
        },
      },
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = (function()
      if jit.os == "Windows" then
        return "pwsh -NoProfile Build.ps1"
      else
        return "make"
      end
    end)(),
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
        lazy = true,
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },

  -- {
  --   'milanglacier/minuet-ai.nvim',
  --   config = function()
  --     require('minuet').setup {
  --       provider = 'openai_fim_compatible',
  --       n_completions = 1, -- recommend for local model for resource saving
  --       -- I recommend you start with a small context window firstly, and gradually
  --       -- increase it based on your local computing power.
  --       context_window = 512,
  --       provider_options = {
  --         openai_fim_compatible = {
  --           api_key = 'TERM',
  --           name = 'Ollama',
  --           end_point = 'http://localhost:11434/v1/completions',
  --           model = "deepseek-coder:6.7b",
  --           optional = {
  --             max_tokens = 256,
  --             top_p = 0.9,
  --           },
  --         },
  --       },
  --     }
  --   end,
  -- },
}
