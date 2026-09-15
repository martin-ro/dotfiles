local M = {}

local config = {
  include_body = false,
  same_workspace_only = false,
  auto_send_single = false,
}

local function herdr(args)
  local result = vim.system(vim.list_extend({ "herdr" }, args), { text = true }):wait()
  if result.code ~= 0 then
    return nil, (result.stderr ~= "" and result.stderr or result.stdout)
  end
  return result.stdout
end

local function list_panes()
  local out, err = herdr({ "pane", "list" })
  if not out then
    return nil, err
  end
  local ok, decoded = pcall(vim.json.decode, out)
  if not ok or type(decoded) ~= "table" then
    return nil, "could not parse 'herdr pane list' output"
  end
  return decoded.result and decoded.result.panes or {}
end

local function candidate_panes()
  local panes, err = list_panes()
  if not panes then
    return nil, err
  end

  local self_id = vim.env.HERDR_PANE_ID
  local self_workspace = vim.env.HERDR_WORKSPACE_ID
  local self_tab = vim.env.HERDR_TAB_ID
  if not self_id then
    for _, p in ipairs(panes) do
      if p.focused then
        self_id, self_workspace, self_tab = p.pane_id, p.workspace_id, p.tab_id
      end
    end
  end

  local candidates = {}
  for _, p in ipairs(panes) do
    local in_scope = not config.same_workspace_only or p.workspace_id == self_workspace
    if p.agent and p.pane_id ~= self_id and in_scope then
      table.insert(candidates, p)
    end
  end

  table.sort(candidates, function(a, b)
    local aw = a.workspace_id == self_workspace
    local bw = b.workspace_id == self_workspace
    if aw ~= bw then
      return aw
    end
    local ai = a.agent_status == "idle"
    local bi = b.agent_status == "idle"
    if ai ~= bi then
      return ai
    end
    local at = a.tab_id == self_tab
    local bt = b.tab_id == self_tab
    if at ~= bt then
      return at
    end
    return tostring(a.pane_id) < tostring(b.pane_id)
  end)

  return candidates, nil, self_workspace
end

local function herdr_json(args)
  local out, err = herdr(args)
  if not out then
    return nil, err
  end
  local ok, decoded = pcall(vim.json.decode, out)
  if not ok or type(decoded) ~= "table" then
    return nil, "could not parse herdr output"
  end
  return decoded.result
end

local function workspace_labels(candidates, self_workspace)
  local needed = false
  for _, c in ipairs(candidates) do
    if c.workspace_id ~= self_workspace then
      needed = true
      break
    end
  end
  if not needed then
    return {}
  end

  local labels = {}
  local res = herdr_json({ "workspace", "list" })
  for _, w in ipairs(res and res.workspaces or {}) do
    labels[w.workspace_id] = w.label or ("workspace " .. tostring(w.number))
  end
  return labels
end

local function enrich(candidates, self_workspace)
  local ws_labels = workspace_labels(candidates, self_workspace)
  local tab_labels = {}
  for _, c in ipairs(candidates) do
    local pane_label = c.label
    if not pane_label then
      local res = herdr_json({ "pane", "get", c.pane_id })
      pane_label = res and res.pane and res.pane.label
    end

    if c.tab_id and tab_labels[c.tab_id] == nil then
      local res = herdr_json({ "tab", "get", c.tab_id })
      local tab = res and res.tab
      tab_labels[c.tab_id] = tab and (tab.label or ("tab " .. tostring(tab.number))) or false
    end

    local name = pane_label or c.agent or c.pane_id
    if c.agent and name ~= c.agent then
      name = name .. " (" .. c.agent .. ")"
    end
    local status = c.agent_status or "?"
    local parts = {}
    if c.workspace_id ~= self_workspace and ws_labels[c.workspace_id] then
      table.insert(parts, ws_labels[c.workspace_id])
    end
    local tab_label = c.tab_id and tab_labels[c.tab_id]
    if tab_label then
      table.insert(parts, tab_label)
    end
    table.insert(parts, name)
    c.display = string.format("%s  [%s]", table.concat(parts, " · "), status)
  end
  return candidates
end

local function send(pane_id, payload)
  local _, err = herdr({ "pane", "send-text", pane_id, payload })
  if err then
    return false, err
  end
  local _, key_err = herdr({ "pane", "send-keys", pane_id, "Enter" })
  if key_err then
    return false, key_err
  end
  return true
end

local function dispatch(ref, body)
  vim.ui.input({ prompt = "note → " }, function(note)
    if note == nil then
      return
    end

    local payload = ref
    if note ~= "" then
      payload = payload .. " " .. note
    end
    if config.include_body and body and body ~= "" then
      payload = payload .. "\n\n" .. body
    end

    local candidates, err, self_workspace = candidate_panes()
    if not candidates then
      vim.notify("herdr-agent: " .. err, vim.log.levels.ERROR)
      return
    end
    if #candidates == 0 then
      vim.notify("herdr-agent: no other agent panes found", vim.log.levels.WARN)
      return
    end

    enrich(candidates, self_workspace)

    local function deliver(pane)
      local ok, send_err = send(pane.pane_id, payload)
      if ok then
        vim.notify("herdr-agent: sent " .. ref .. " → " .. (pane.display or pane.pane_id))
      else
        vim.notify("herdr-agent: send failed: " .. send_err, vim.log.levels.ERROR)
      end
    end

    if config.auto_send_single and #candidates == 1 then
      deliver(candidates[1])
      return
    end

    vim.ui.select(candidates, {
      prompt = "discuss with →",
      format_item = function(p)
        return p.display or p.pane_id
      end,
    }, function(choice)
      if choice then
        deliver(choice)
      end
    end)
  end)
end

local function relative_path()
  local path = vim.fn.expand("%:.")
  if path == "" then
    return nil
  end
  return path
end

function M.discuss()
  vim.cmd([[execute "normal! \<Esc>"]])
  local path = relative_path()
  if not path then
    vim.notify("herdr-agent: buffer has no file path", vim.log.levels.WARN)
    return
  end

  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local loc = start_line == end_line
      and string.format(" (line %d)", start_line)
      or string.format(" (lines %d-%d)", start_line, end_line)
  local ref = "@" .. path .. loc

  local body
  if config.include_body then
    body = table.concat(vim.fn.getline(start_line, end_line), "\n")
  end

  dispatch(ref, body)
end

function M.discuss_here()
  local path = relative_path()
  if not path then
    vim.notify("herdr-agent: buffer has no file path", vim.log.levels.WARN)
    return
  end

  local line = vim.fn.line(".")
  local ref = string.format("@%s (line %d)", path, line)
  local body = config.include_body and vim.fn.getline(line) or nil
  dispatch(ref, body)
end

function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

return M
