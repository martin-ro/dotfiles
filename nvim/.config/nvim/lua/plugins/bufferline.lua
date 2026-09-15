return {
  {
    "akinsho/bufferline.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({
        options = {
          modified_icon = "•",
          custom_filter = function(buf_number)
            local name = vim.api.nvim_buf_get_name(buf_number)
            local buftype = vim.bo[buf_number].buftype
            if name == "" and buftype == "" then
              return false
            end
            return true
          end,
        },
      })

      vim.keymap.set("n", "<S-l>", ":BufferLineCycleNext<CR>")
      vim.keymap.set("n", "<S-h>", ":BufferLineCyclePrev<CR>")
      vim.keymap.set("n", "<leader>x", ":confirm bdelete<CR>", { desc = "Close buffer" })
      vim.keymap.set("n", "<leader>bo", ":BufferLineCloseOthers<CR>")
      vim.keymap.set("n", "<leader>bD", ":%bdelete<CR>")
    end,
  },
}
