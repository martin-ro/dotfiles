return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "intelephense" },
      })

      -- Neovim doesn't advertise LSP file watching on Linux because its
      -- fallback backends are slow on big trees. With inotifywait installed
      -- it uses the cheap inotify backend instead, so opt in: the server
      -- then notices files created outside nvim (artisan make, installers)
      -- without needing an :LspRestart.
      local capabilities = {}
      if vim.fn.executable("inotifywait") == 1 then
        capabilities.workspace = {
          didChangeWatchedFiles = { dynamicRegistration = true },
        }
      end

      vim.lsp.config("intelephense", { capabilities = capabilities })
      vim.lsp.enable("intelephense")

      -- Official Laravel LSP (composer global require laravel/lsp).
      -- Runs alongside intelephense: it only adds Laravel-specific features
      -- (routes, views, config keys, Eloquent) and Blade support.
      vim.lsp.config("laravel_lsp", {
        cmd = { "laravel-lsp" },
        filetypes = { "php", "blade" },
        root_markers = { "artisan" },
        capabilities = capabilities,
      })
      vim.lsp.enable("laravel_lsp")

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local opts = { buffer = args.buf, silent = true }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        end,
      })

      -- Diagnostic keymaps (work globally, not just when a server is attached)
      vim.keymap.set("n", "<leader>cd", function()
        local _, winid = vim.diagnostic.open_float()
        if not winid then
          vim.notify("No diagnostics on this line", vim.log.levels.INFO)
        end
      end, { desc = "Line diagnostics" })
      vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
      vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Prev diagnostic" })

      -- Gutter icons instead of the E/W/I/H letters
      vim.diagnostic.config({
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.INFO] = "",
            [vim.diagnostic.severity.HINT] = "●",
          },
        },
      })
    end,
  },
}
