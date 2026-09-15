-- Set leader key before lazy
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

 -- Load plugins from lua/plugins/
require("lazy").setup("plugins")

-- Basic options
vim.opt.number = false          -- line numbers
vim.opt.relativenumber = false  -- relative line numbers
vim.opt.tabstop = 4             -- tab width
vim.opt.shiftwidth = 4          -- indent width
vim.opt.expandtab = true        -- spaces instead of tabs
vim.opt.wrap = false            -- no line wrap
vim.opt.termguicolors = true    -- true color support
vim.opt.signcolumn = "yes"      -- always reserve gutter space (no text shift)

-- System clipboard via OSC 52 (yanks travel back to the local Mac over SSH/herdr).
-- Copy goes out through the terminal; paste stays local to Neovim's registers,
-- since OSC 52 read-back is unreliable across terminals.
vim.opt.clipboard = "unnamedplus"
local osc52 = require("vim.ui.clipboard.osc52")
vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = osc52.copy("+"),
    ["*"] = osc52.copy("*"),
  },
  paste = {
    ["+"] = function() return vim.fn.getreg("", 1, true) end,
    ["*"] = function() return vim.fn.getreg("", 1, true) end,
  },
}

-- Persistent undo (history survives closing/quitting)
vim.opt.undofile = true         -- save undo history to disk
vim.opt.undolevels = 1000       -- max changes that can be undone
-- undodir defaults to stdpath("state").."/undo" and is auto-created by Neovim

-- Keymaps
vim.keymap.set("n", "<leader>y", ":let @+=expand('%:p')<CR>", { desc = "Copy absolute file path to clipboard" })

-- Send code references to a Claude agent in another herdr pane
local herdr_agent = require("herdr_agent")
vim.keymap.set("x", "<leader>as", herdr_agent.discuss, { desc = "Send selection to a herdr agent" })
vim.keymap.set("n", "<leader>aa", herdr_agent.discuss_here, { desc = "Ask a herdr agent about this line" })

-- Folding
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99          -- open all folds by default