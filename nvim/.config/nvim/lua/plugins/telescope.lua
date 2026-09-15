return {
 {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        defaults = {
          sorting_strategy = "ascending",
          layout_config = {
            prompt_position = "top",
          },
        },
        pickers = {
          find_files = {
            -- Show dotfiles (e.g. .env.example) but keep respecting .gitignore,
            -- so genuinely ignored files like .env stay hidden.
            hidden = true,
          },
        },
      })

      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files)
      vim.keymap.set("n", "<leader>fg", builtin.live_grep)

      -- Grep the word under the cursor (normal) or the visual selection.
      vim.keymap.set("n", "<leader>fw", builtin.grep_string)
      vim.keymap.set("x", "<leader>fw", builtin.grep_string)

      -- Find files including gitignored ones (e.g. .env), but skip the big
      -- ignored dirs so there's no vendor/node_modules noise.
      vim.keymap.set("n", "<leader>fa", function()
        builtin.find_files({
          find_command = {
            "fd", "--type", "f", "--hidden", "--no-ignore",
            "--exclude", ".git",
            "--exclude", "vendor",
            "--exclude", "node_modules",
          },
        })
      end)
    end,
  },
}
