local M = {}

function M.setup()
  vim.diagnostic.config({
    virtual_text = {
      severity = { min = vim.diagnostic.severity.WARN },
      source = "if_many",
      spacing = 4,
    },
    signs = true,
    update_in_insert = false,
    severity_sort = true,
  })
end

return M
