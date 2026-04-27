local M = {}

function M.setup(opts)
  opts = opts or {}

  require("core.options").setup()
  require("core.autocmds").setup()
  require("core.diagnostics").setup()

  if opts.ui ~= false then
    require("core.ui").setup()
  end
end

return M
