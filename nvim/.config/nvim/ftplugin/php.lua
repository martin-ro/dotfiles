local function complete_statement()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line():gsub("%s+$", "")
  local indent = line:match("^%s*") or ""
  local sw = vim.bo.shiftwidth ~= 0 and vim.bo.shiftwidth or vim.bo.tabstop
  local unit = vim.bo.expandtab and string.rep(" ", sw) or "\t"
  local inner = indent .. unit

  local allman = line:match("function%s+[%w_]")
    or line:match("^%s*[%w%s]-class%s")
    or line:match("^%s*interface%s")
    or line:match("^%s*trait%s")
    or line:match("^%s*enum%s")

  local lines, cursor_row
  if allman then
    lines = { line, indent .. "{", inner, indent .. "}" }
    cursor_row = row + 2
  else
    lines = { line .. " {", inner, indent .. "}" }
    cursor_row = row + 1
  end

  vim.api.nvim_buf_set_lines(0, row - 1, row, false, lines)
  vim.api.nvim_win_set_cursor(0, { cursor_row, #inner })
end

vim.keymap.set("i", "<C-j>", complete_statement, {
  buffer = true,
  desc = "Complete statement (open brace block, cursor inside)",
})

local pest = require("pest")

vim.keymap.set("n", "<leader>tn", pest.nearest, { buffer = true, desc = "Pest: nearest test (serial)" })
vim.keymap.set("n", "<leader>tf", pest.file, { buffer = true, desc = "Pest: this file (serial)" })
vim.keymap.set("n", "<leader>td", pest.directory, { buffer = true, desc = "Pest: this directory (parallel)" })
vim.keymap.set("n", "<leader>tl", pest.last, { buffer = true, desc = "Pest: re-run last" })
