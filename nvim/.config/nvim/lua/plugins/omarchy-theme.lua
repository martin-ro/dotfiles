return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    lazy = false,
    priority = 1000,
    config = function()
      local function opts_from_spec(path)
        if vim.fn.filereadable(path) ~= 1 then
          return nil
        end
        local ok, spec = pcall(dofile, path)
        if not ok or type(spec) ~= "table" or type(spec[1]) ~= "table" then
          return nil
        end
        local name = spec[1][1] or spec[1].name
        if type(name) ~= "string" or not name:find("aether", 1, true) then
          return nil
        end
        return spec[1].opts
      end

      local function opts_from_toml(path)
        if vim.fn.filereadable(path) ~= 1 then
          return nil
        end
        local c = {}
        for line in io.lines(path) do
          local k, v = line:match('^(%w+)%s*=%s*"(#[0-9a-fA-F]+)"')
          if k then
            c[k] = v
          end
        end
        if not c.background then
          return nil
        end
        return {
          colors = {
            bg = c.background,
            dark_bg = c.dark_background,
            darker_bg = c.darker_background,
            lighter_bg = c.lighter_background,
            fg = c.foreground,
            dark_fg = c.dark_foreground,
            light_fg = c.light_foreground,
            bright_fg = c.bright_foreground,
            muted = c.muted,
            red = c.red,
            yellow = c.yellow,
            orange = c.orange,
            green = c.green,
            cyan = c.cyan,
            blue = c.blue,
            magenta = c.magenta,
            brown = c.brown,
            bright_red = c.bright_red,
            bright_yellow = c.bright_yellow,
            bright_green = c.bright_green,
            bright_cyan = c.bright_cyan,
            bright_blue = c.bright_blue,
            bright_magenta = c.bright_magenta,
            accent = c.accent,
            cursor = c.bright_foreground,
            foreground = c.foreground,
            background = c.background,
            selection = c.selection,
            selection_foreground = c.selection_foreground or c.bright_foreground,
            selection_background = c.selection_background or c.selection,
          },
        }
      end

      local opts = opts_from_spec(vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua"))
        or opts_from_spec(vim.fn.expand("~/.config/aether/theme/neovim.lua"))
        or opts_from_toml(vim.fn.expand("~/.local/state/omarchy/current/theme/colors.toml"))

      if opts then
        require("aether").setup(opts)
      end
      vim.cmd.colorscheme("aether")
    end,
  },
}
