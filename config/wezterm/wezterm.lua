-- ~/.wezterm.lua
-- A pimped-up WezTerm config 🚀
-- Docs: https://wezfurlong.org/wezterm/config/files.html

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

--------------------------------------------------------------------------------
-- Appearance / Theme
--------------------------------------------------------------------------------
config.color_scheme = "Catppuccin Mocha" -- try: "Tokyo Night", "Dracula", "Nord"

-- Font: falls back through this list to whatever you have installed.
config.font = wezterm.font_with_fallback({
  "Comic Code Ligatures",
  "JetBrainsMono Nerd Font",
  "JetBrains Mono",
  "Cascadia Code",
  "Consolas",
})
config.font_size = 11.0
config.line_height = 1.05
config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" } -- ligatures

-- Window
config.window_background_opacity = 0.96
config.macos_window_background_blur = 20 -- harmless on Windows

-- Anime background: pick a RANDOM image from the backgrounds folder at startup.
-- Drop any number of .png/.jpg files in ~/.config/wezterm/backgrounds and one is
-- chosen each time the config loads (i.e. each new WezTerm launch).
local bg_dir = wezterm.home_dir .. "/.config/wezterm/backgrounds"
local images = {}
for _, pat in ipairs({ "/*.png", "/*.jpg", "/*.jpeg", "/*.webp" }) do
  for _, f in ipairs(wezterm.glob(bg_dir .. pat)) do
    images[#images + 1] = f
  end
end

if #images > 0 then
  math.randomseed(os.time() + os.clock() * 1000)
  local pick = images[math.random(#images)]
  config.background = {
    -- Base solid color layer (matches Catppuccin Mocha base) behind the image
    { source = { Color = "#1e1e2e" }, width = "100%", height = "100%" },
    -- The randomly chosen waifu, anchored right, dimmed for readability
    {
      source = { File = pick },
      horizontal_align = "Right",
      vertical_align = "Middle",
      repeat_x = "NoRepeat",
      repeat_y = "NoRepeat",
      width = "Cover",
      height = "Cover",
      opacity = 1.0,
      hsb = { brightness = 0.12, saturation = 1.0, hue = 1.0 }, -- dim the picture
    },
  }
  -- Keep terminal text crisp over the image
  config.text_background_opacity = 1.0
end
config.window_decorations = "RESIZE"
config.window_padding = { left = 12, right = 12, top = 10, bottom = 8 }
config.initial_cols = 120
config.initial_rows = 32
config.adjust_window_size_when_changing_font_size = false

-- Cursor
config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- Scrollback
config.scrollback_lines = 10000
config.enable_scroll_bar = false

--------------------------------------------------------------------------------
-- Tab bar
--------------------------------------------------------------------------------
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false
config.tab_max_width = 28
config.show_new_tab_button_in_tab_bar = true

-- Show a clean index + title on each tab and a clock in the right status.
wezterm.on("format-tab-title", function(tab, _tabs, _panes, _config, _hover, max_width)
  local title = tab.tab_title
  if not title or #title == 0 then
    title = tab.active_pane.title
  end
  title = wezterm.truncate_right(title, max_width - 6)
  local idx = tab.tab_index + 1
  return {
    { Text = "  " .. idx .. ": " .. title .. "  " },
  }
end)

wezterm.on("update-right-status", function(window, _pane)
  local date = wezterm.strftime("%a %b %-d  %H:%M")
  window:set_right_status(wezterm.format({
    { Foreground = { Color = "#89b4fa" } },
    { Text = " " .. date .. "  " },
  }))
end)

--------------------------------------------------------------------------------
-- Default shell (Windows): prefer PowerShell, fall back to cmd
--------------------------------------------------------------------------------
if wezterm.target_triple:find("windows") then
  config.default_prog = { "powershell.exe", "-NoLogo" }
  config.launch_menu = {
    { label = "PowerShell", args = { "powershell.exe", "-NoLogo" } },
    { label = "Command Prompt", args = { "cmd.exe" } },
    { label = "Git Bash", args = { "C:\\Program Files\\Git\\bin\\bash.exe", "-i", "-l" } },
  }
end

--------------------------------------------------------------------------------
-- Cheat sheet overlay
--   Pops up a searchable list of the common keybindings and STAYS UP until you
--   press a key (Esc to dismiss, or Enter on an entry to run that action).
--------------------------------------------------------------------------------
-- Each entry: { keys = "shown shortcut", desc = "what it does", action = <optional act> }
local cheat_entries = {
  { keys = "Ctrl+a  \\",      desc = "Split pane horizontally", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { keys = "Ctrl+a  -",       desc = "Split pane vertically",   action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { keys = "Ctrl+a  h/j/k/l", desc = "Move between panes (left/down/up/right)" },
  { keys = "Ctrl+a  z",       desc = "Zoom / unzoom current pane", action = act.TogglePaneZoomState },
  { keys = "Ctrl+a  x",       desc = "Close current pane",      action = act.CloseCurrentPane({ confirm = true }) },
  { keys = "Ctrl+a  c",       desc = "New tab",                 action = act.SpawnTab("CurrentPaneDomain") },
  { keys = "Ctrl+a  n / p",   desc = "Next / previous tab" },
  { keys = "Ctrl+a  1-9",     desc = "Jump to tab N" },
  { keys = "Ctrl + = / - / 0",desc = "Font size up / down / reset" },
  { keys = "Ctrl+Shift+C / V",desc = "Copy / paste clipboard" },
  { keys = "Ctrl+Shift+P",    desc = "Command palette",         action = act.ActivateCommandPalette },
  { keys = "Ctrl+Shift+F",    desc = "Search scrollback",       action = act.Search({ CaseInSensitiveString = "" }) },
  { keys = "Ctrl+a  Ctrl+l",  desc = "Show launcher menu",      action = act.ShowLauncher },
  { keys = "Alt+Enter",       desc = "Toggle fullscreen",       action = act.ToggleFullScreen },
  { keys = "F1  /  Ctrl+a ?", desc = "Show this cheat sheet" },
}

local function show_cheatsheet(window, pane)
  local choices = {}
  for _, e in ipairs(cheat_entries) do
    -- pad the shortcut column so descriptions line up
    local key_col = e.keys .. string.rep(" ", math.max(1, 18 - #e.keys))
    table.insert(choices, {
      id = tostring(#choices + 1),
      label = wezterm.format({
        { Foreground = { Color = "#f9e2af" } }, { Text = key_col },
        { Foreground = { Color = "#cdd6f4" } }, { Text = "  " .. e.desc },
      }),
    })
  end
  window:perform_action(
    act.InputSelector({
      title = "  Keybinding Cheat Sheet  (Esc to close, Enter to run)",
      choices = choices,
      fuzzy = true,
      fuzzy_description = "Search keybindings: ",
      action = wezterm.action_callback(function(win, p, id, _label)
        if not id then return end -- Esc pressed
        local entry = cheat_entries[tonumber(id)]
        if entry and entry.action then
          win:perform_action(entry.action, p)
        end
      end),
    }),
    pane
  )
end

wezterm.on("show-cheatsheet", show_cheatsheet)

--------------------------------------------------------------------------------
-- Keybindings (LEADER = Ctrl+a, tmux-style)
--------------------------------------------------------------------------------
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
  -- Splits
  { key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

  -- Pane navigation
  { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
  { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
  { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
  { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
  { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },

  -- Tabs
  { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
  { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },

  -- Quick font size
  { key = "=", mods = "CTRL", action = act.IncreaseFontSize },
  { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
  { key = "0", mods = "CTRL", action = act.ResetFontSize },

  -- Clipboard
  { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
  { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },

  -- Command palette & launcher
  { key = "P", mods = "CTRL|SHIFT", action = act.ActivateCommandPalette },
  { key = "l", mods = "LEADER|CTRL", action = act.ShowLauncher },

  -- Quick-select / search
  { key = "f", mods = "CTRL|SHIFT", action = act.Search({ CaseInSensitiveString = "" }) },

  -- Cheat sheet overlay (stays up until you press a key)
  { key = "F1", action = act.EmitEvent("show-cheatsheet") },
  { key = "?", mods = "LEADER", action = act.EmitEvent("show-cheatsheet") },
}

-- Jump to tab N with LEADER + number
for i = 1, 9 do
  table.insert(config.keys, {
    key = tostring(i),
    mods = "LEADER",
    action = act.ActivateTab(i - 1),
  })
end

--------------------------------------------------------------------------------
-- Misc niceties
--------------------------------------------------------------------------------
config.audible_bell = "Disabled"
config.window_close_confirmation = "NeverPrompt"
config.front_end = "WebGpu" -- smooth GPU rendering
config.animation_fps = 60
config.max_fps = 120

return config
