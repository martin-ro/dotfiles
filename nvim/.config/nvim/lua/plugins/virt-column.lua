return {
  "lukas-reineke/virt-column.nvim",
  enabled = false,
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    char = "▏",              -- thin 1px-style vertical line (U+258F)
    virtcolumn = "80",       -- column to mark
    highlight = "VirtColumn", -- use our own group so the color below applies
  },
  config = function(_, opts)
    require("virt-column").setup(opts)

    -- Follow the active colorscheme instead of a fixed color
    local function set_hl()
      vim.api.nvim_set_hl(0, "VirtColumn", { link = "Whitespace" })
    end

    set_hl()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })
  end,
}
