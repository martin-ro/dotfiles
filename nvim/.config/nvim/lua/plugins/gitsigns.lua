return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    signs = {
      add          = { text = "▎" },
      change       = { text = "▎" },
      delete       = { text = "▁" },
      topdelete    = { text = "▔" },
      changedelete = { text = "▎" },
    },
  },
  config = function(_, opts)
    require("gitsigns").setup(opts)

    vim.api.nvim_set_hl(0, "GitSignsAdd", { fg = "#98c379" })
    vim.api.nvim_set_hl(0, "GitSignsChange", { fg = "#e5a04b" })
    vim.api.nvim_set_hl(0, "GitSignsDelete", { fg = "#e06c75" })
    vim.api.nvim_set_hl(0, "GitSignsTopdelete", { fg = "#e06c75" })
    vim.api.nvim_set_hl(0, "GitSignsChangedelete", { fg = "#e5a04b" })
  end,
}
