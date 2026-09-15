return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup()

      -- Parsers to install (main branch installs are async/idempotent)
      require("nvim-treesitter").install({
        "php", "blade", "lua", "javascript", "typescript", "tsx", "html", "css", "json", "bash", "yaml",
      })

      -- Detect Blade files. The parser is named "blade" and matches the
      -- "blade" filetype, so treesitter picks it up automatically.
      vim.filetype.add({
        pattern = {
          [".*%.blade%.php"] = "blade",
        },
      })

      -- Main branch does NOT auto-enable highlighting; do it per filetype.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "php", "blade", "lua", "javascript", "javascriptreact", "typescript", "typescriptreact", "html", "css", "json", "bash" },
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })
    end,
  },
}
