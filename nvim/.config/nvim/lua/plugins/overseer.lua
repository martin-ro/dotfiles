return {
  "stevearc/overseer.nvim",
  cmd = {
    "OverseerRun",
    "OverseerRunCmd",
    "OverseerToggle",
    "OverseerOpen",
    "OverseerQuickAction",
    "OverseerTaskAction",
  },
  opts = {},
  keys = {
    -- Run a task (auto-discovers npm scripts, VS Code tasks, etc.)
    { "<leader>ro", "<cmd>OverseerRun<cr>", desc = "Overseer: run task" },
    -- Run an arbitrary shell command (e.g. type "npm run dev")
    { "<leader>rc", "<cmd>OverseerRunCmd<cr>", desc = "Overseer: run command" },
    -- Toggle the task list panel (start/stop/restart from here)
    { "<leader>rt", "<cmd>OverseerToggle<cr>", desc = "Overseer: toggle task list" },
    -- Quick action on a task: restart, stop, dispose, etc.
    { "<leader>ra", "<cmd>OverseerQuickAction<cr>", desc = "Overseer: quick action" },
  },
}
