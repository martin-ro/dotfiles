return {
  {
    "sindrets/diffview.nvim",
    keys = {
      {
        "<leader>gd",
        function()
          local lib = require("diffview.lib")
          if lib.get_current_view() then
            vim.cmd("DiffviewClose")
          else
            vim.cmd("DiffviewOpen")
          end
        end,
        desc = "Toggle Git Diff View",
      },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File Git History" },
    },
    opts = {},
  },
}
