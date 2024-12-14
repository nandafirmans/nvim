return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup();

      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end

      vim.keymap.set("n", "<leader>bt", dap.toggle_breakpoint, {});
      vim.keymap.set("n", "<leader>bc", dap.continue, {});
      vim.keymap.set("n", "<leader>bi", dap.step_into, {});
      vim.keymap.set("n", "<leader>bn", dap.step_over, {});
      vim.keymap.set("n", "<leader>bq", dap.terminate, {});
      vim.keymap.set("n", "<A-B>", dapui.open, {});
      vim.keymap.set("n", "<A-b>", dapui.close, {});

      dap.adapters.chrome = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
          command = "node",
          args = {
            require("mason-registry")
            .get_package("js-debug-adapter")
            :get_install_path()
            .. "/js-debug/src/dapDebugServer.js",
            "${port}",
          },
        },
      }
      for _, lang in ipairs({
        "typescript",
        "javascript",
        "typescriptreact",
        "javascriptreact",
      }) do
        dap.configurations[lang] = dap.configurations[lang] or {}
        table.insert(dap.configurations[lang], {
          type = "chrome",
          request = "launch",
          name = "Launch Chrome",
          url = "http://localhost:3000",
          webRoot = vim.fn.getcwd(),
          sourceMaps = true,
        })
        table.insert(dap.configurations[lang], {
          type = "chrome",
          request = "attach",
          program = "${file}",
          cwd = vim.fn.getcwd(),
          sourceMaps = true,
          protocol = "inspector",
          port = 9222,
          webRoot = "${workspaceFolder}"
        })
      end


      -- local baseDapConfigJs = {
      --   {
      --     type = "chrome",
      --     request = "attach",
      --     program = "${file}",
      --     cwd = vim.fn.getcwd(),
      --     sourceMaps = true,
      --     protocol = "inspector",
      --     port = 9222,
      --     webRoot = "${workspaceFolder}"
      --   }
      -- }
      --
      -- dap.configurations.javascript = baseDapConfigJs
      -- dap.configurations.typescript = baseDapConfigJs
      -- dap.configurations.javascriptreact = baseDapConfigJs
      -- dap.configurations.typescriptreact = baseDapConfigJs
    end
  },
  { "rcarriga/nvim-dap-ui", dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" } },
  {
    'nicholasmata/nvim-dap-cs',
    dependencies = { 'mfussenegger/nvim-dap' },
    config = function()
      require('dap-cs').setup()
    end
  },
  {
    "Cliffback/netcoredbg-macOS-arm64.nvim",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      if vim.fn.has("mac") == 0 then
        return
      end

      require('netcoredbg-macOS-arm64').setup(require('dap'))
    end
  }
}
