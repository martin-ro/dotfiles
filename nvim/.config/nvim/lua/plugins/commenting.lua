return {
  {
    "JoosepAlviste/nvim-ts-context-commentstring",
    -- Relies on treesitter parsers with injections (blade, html, php, js, css),
    -- which are installed in treesitter.lua.
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    lazy = false,
    config = function()
      -- We drive commenting through Neovim's built-in gc/gcc, not the legacy
      -- nvim-treesitter module, so skip that integration (also silences a warning).
      vim.g.skip_ts_context_commentstring_module = true

      require("ts_context_commentstring").setup({
        enable_autocmd = false,
        languages = {
          -- The blade parser's top-level language has no built-in default.
          blade = "{{-- %s --}}",
        },
      })

      -- Neovim's built-in commenting reads the commentstring via
      -- vim.filetype.get_option. Override it to return the treesitter-calculated,
      -- cursor-aware value, falling back to the filetype default when there is none.
      local get_option = vim.filetype.get_option
      vim.filetype.get_option = function(filetype, option)
        return option == "commentstring"
            and require("ts_context_commentstring.internal").calculate_commentstring()
          or get_option(filetype, option)
      end
    end,
  },
}
