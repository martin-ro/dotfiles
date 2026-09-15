return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>f",
      function()
        require("conform").format({ async = true })
      end,
      mode = { "n", "v" },
      desc = "Format buffer (Pint)",
    },
  },
  opts = function()
    local util = require("conform.util")

    return {
      formatters_by_ft = {
        php = { "pint" },
        blade = { "blade-formatter" },
        html = { "prettier" },
        css = { "prettier" },
        scss = { "prettier" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
      },
      format_on_save = {
        timeout_ms = 3000,
        lsp_format = "never",
      },
      formatters = {
        pint = {
          -- Prefer the project's binary (respects its pint.json); fall back to PATH.
          command = util.find_executable({ "vendor/bin/pint" }, "pint"),
          -- Run from the dir containing pint.json/composer.json so rules are applied.
          cwd = util.root_file({ "pint.json", "composer.json" }),
        },
      },
    }
  end,
}
