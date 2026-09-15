return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("neo-tree").setup({
        filesystem = {
          filtered_items = {
            hide_dotfiles = false,
          },
        },
        window = {
          mappings = {
            ["<C-Left>"] = function() vim.cmd("vertical resize -5") end,
            ["<C-Right>"] = function() vim.cmd("vertical resize +5") end,
          },
        },
      })

      vim.keymap.set("n", "<leader>e", ":Neotree toggle<CR>")
      vim.keymap.set("n", "<leader>gs", ":Neotree git_status<CR>")
    end,
  },
}
