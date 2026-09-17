hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 5,
    border_size = 3,
  },

  decoration = {
    rounding = 8,
  },
})

-- Float Gmail, Google Calendar, Google Tasks, and WhatsApp web apps.
o.window("^chrome-((mail|calendar|tasks)[.]google[.]com|web[.]whatsapp[.]com)__.*$", { float = true, center = true, size = { "monitor_w*0.5", "monitor_h*0.9" } })
o.window({ class = "^Bitwarden$", tag = "floating-window" }, { size = { "monitor_w*0.5", "monitor_h*0.9" } })
