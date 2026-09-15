-- Scope-aware Pest runner routed through overseer.
--
-- Pest parallelizes by FILE, so --parallel only pays off once you're running a
-- directory's worth of files. Nearest-test and single-file runs stay serial
-- (paratest worker startup would just be dead weight there); the directory
-- scope opts into --parallel.

local M = {}

local last = nil

-- Pest prints the failure origin as "  at tests/Feature/FooTest.php:42",
-- relative to the project root. Match only that line so the quickfix list is
-- failure locations, not every stack frame.
local errorformat = "%.%#at %f:%l"

local function project_root()
  local artisan = vim.fs.find({ "artisan" }, {
    upward = true,
    path = vim.api.nvim_buf_get_name(0),
  })[1]

  return artisan and vim.fs.dirname(artisan) or vim.fn.getcwd()
end

local function relative_to(path, root)
  return (path:gsub("^" .. vim.pesc(root) .. "/", ""))
end

-- PHPUnit's --filter value is a regex; escape it so the test description
-- matches literally (parens, dots, etc. are common in descriptions).
local function escape_filter(description)
  return (description:gsub("[%(%)%.%+%-%*%?%[%]%^%$|]", "\\%0"))
end

local function strip_quotes(text)
  return (text:gsub("^['\"]", ""):gsub("['\"]$", ""))
end

-- Walk up the syntax tree to the enclosing test()/it() call and read its
-- description argument. Falls back to a line scan when treesitter is unavailable.
local function nearest_description()
  local ok, parser = pcall(vim.treesitter.get_parser, 0, "php")

  if ok and parser then
    local root = parser:parse()[1]:root()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local node = root:named_descendant_for_range(row - 1, col, row - 1, col)

    while node do
      if node:type() == "function_call_expression" then
        local fn = node:field("function")[1]
        local name = fn and vim.treesitter.get_node_text(fn, 0)

        if name == "test" or name == "it" then
          local args = node:field("arguments")[1]

          for child in args:iter_children() do
            if child:named() then
              return strip_quotes(vim.treesitter.get_node_text(child, 0))
            end
          end
        end
      end

      node = node:parent()
    end
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]

  for line = row, 1, -1 do
    local text = vim.fn.getline(line)
    local description = text:match("^%s*it%s*%(%s*['\"](.-)['\"]")
      or text:match("^%s*test%s*%(%s*['\"](.-)['\"]")

    if description then
      return description
    end
  end

  return nil
end

local function run(args, label)
  local overseer = require("overseer")
  local root = project_root()

  last = { args = args, label = label }

  local cmd = { "php", "artisan", "test" }
  vim.list_extend(cmd, args)

  local task = overseer.new_task({
    name = label,
    cmd = cmd,
    cwd = root,
    components = {
      {
        "on_output_quickfix",
        errorformat = errorformat,
        relative_file_root = root,
        open = true,
        close = true,
        tail = false,
      },
      "default",
    },
  })

  task:start()
  overseer.open({ enter = false })
end

function M.nearest()
  local description = nearest_description()

  if not description then
    vim.notify("Pest: no test() / it() found above the cursor", vim.log.levels.WARN)

    return
  end

  local file = relative_to(vim.api.nvim_buf_get_name(0), project_root())

  run({ "--compact", file, "--filter=" .. escape_filter(description) }, "pest: " .. description)
end

function M.file()
  local file = relative_to(vim.api.nvim_buf_get_name(0), project_root())

  run({ "--compact", file }, "pest: " .. vim.fn.fnamemodify(file, ":t"))
end

function M.directory()
  local dir = relative_to(vim.fn.expand("%:p:h"), project_root())

  run({ dir, "--parallel" }, "pest ∥: " .. dir)
end

function M.last()
  if not last then
    vim.notify("Pest: nothing to re-run yet", vim.log.levels.WARN)

    return
  end

  run(last.args, last.label)
end

return M
