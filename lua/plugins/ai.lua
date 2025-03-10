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
        model = "claude-3.5-sonnet",
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
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    opts = {
      provider = 'copilot',
      -- provider = "ollama",
      -- vendors = {
      --   ollama = {
      --     __inherited_from = "openai",
      --     api_key_name = "",
      --     ask = "",
      --     endpoint = "http://127.0.0.1:11434/api",
      --     model = "qwen2.5-coder:7b",
      --     parse_curl_args = function(opts, code_opts)
      --       return {
      --         url = opts.endpoint .. "/chat",
      --         headers = {
      --           ["Accept"] = "application/json",
      --           ["Content-Type"] = "application/json",
      --         },
      --         body = {
      --           model = opts.model,
      --           options = {
      --             num_ctx = 16384,
      --           },
      --           messages = require("avante.providers").copilot.parse_messages(code_opts), -- you can make your own message, but this is very advanced
      --           stream = true,
      --         },
      --       }
      --     end,
      --     parse_stream_data = function(data, handler_opts)
      --       local json_data = vim.fn.json_decode(data)
      --       if json_data and json_data.done then
      --         handler_opts.on_complete(nil) -- Properly terminate the stream
      --         return
      --       end
      --       if json_data and json_data.message and json_data.message.content then
      --         local content = json_data.message.content
      --         handler_opts.on_chunk(content)
      --       end
      --     end,
      --   },
      -- },
    },
    build = (function()
      if jit.os == "Windows" then
        return "pwsh -NoProfile Build.ps1"
      else
        return "make"
      end
    end)(),
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      "zbirenbaum/copilot.lua",
      {
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
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
        'MeanderingProgrammer/render-markdown.nvim',
        lazy = true,
        opts = {
          file_types = { "markdown", "Avante", 'copilot-chat' },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },

}
