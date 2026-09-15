local header = [[

WE MUST SHIP

]]

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    dashboard = {
      enabled = true,
      preset = {
        header = header,
      },
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    },
  },
  init = function()
    -- Laravel brand red (#FF2D20).
    local function paint()
      vim.api.nvim_set_hl(0, "SnacksDashboardHeader", { fg = "#FF2D20", bold = true })
    end

    vim.api.nvim_create_autocmd("ColorScheme", { callback = paint })
    paint()
  end,
}
