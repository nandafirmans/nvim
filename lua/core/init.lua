local M = {}

function M.setup(opts)
  opts = opts or {}

  require("core.options").setup()
  require("core.autocmds").setup()
  require("core.diagnostics").setup()

  if opts.ui ~= false then
    require("core.ui").setup()
  end

  require("agents").setup({
    -- wowo: the hub's own agent with your keys (lua/agents/wowo.lua).
    -- api_key is an env var name or a "!command" that prints the key; it is
    -- never written to disk. Without `models`, :AgentsWowo check lists them.
    wowo = {
      model = "omniroute/hermes-main",
      -- "ask", "auto-edit" or "auto"; Shift-Tab in wowo switches while it runs.
      permissions = "ask",
      providers = {
        -- Same OmniRoute as hermes: its key lives in ~/.hermes/.env.
        omniroute = {
          base_url = "http://127.0.0.1:20128/v1",
          api_key = [[!sed -n 's/^OMNIROUTE_API_KEY=//p' ~/.hermes/.env | tr -d "\"'"]],
          context = 872000,
          models = {
            "hermes-main",
            "hermes-deep",
            "hermes-cheap",
            "hermes-code",
            "hermes-fast",
            "hermes-long",
            "cx/gpt-5.6-sol-medium",
            "opencode-go/glm-5.2",
            "opencode-go/kimi-k3",
          },
        },
        -- ["9router"] = { base_url = "https://9router.example.com/v1", api_key = "NINE_ROUTER_API_KEY" },
      },
    },
  })
end

return M
