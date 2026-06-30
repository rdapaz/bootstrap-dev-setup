-- ~/.wezterm.lua
-- A pimped-up WezTerm config ðŸš€
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

-- Anime background: pick a RANDOM image from the backgrounds folder.
-- One is chosen each time the config loads (every new WezTerm launch), and you
-- can reshuffle the current window on demand with  Ctrl+a b  (see keys below).
-- Drop any number of .png/.jpg/.jpeg/.webp files in ~/.config/wezterm/backgrounds.
local bg_dir = wezterm.home_dir .. "/.config/wezterm/backgrounds"
math.randomseed(os.time() + os.clock() * 1000000)

local function list_backgrounds()
  local images = {}
  for _, pat in ipairs({ "/*.png", "/*.jpg", "/*.jpeg", "/*.webp" }) do
    for _, f in ipairs(wezterm.glob(bg_dir .. pat)) do
      images[#images + 1] = f
    end
  end
  return images
end

-- Build a background layer-stack for a given image file and mode.
local function background_for_mode(file, mode)
  local attachment = "Fixed"
  if mode == "parallax" then
    attachment = { Parallax = 0.15 }
  end

  return {
    -- Base solid color layer (matches Catppuccin Mocha base) behind the image
    { source = { Color = "#1e1e2e" }, width = "100%", height = "100%" },
    -- The chosen background, anchored right, dimmed for readability, with optional parallax scroll
    {
      source = { File = file },
      horizontal_align = "Right",
      vertical_align = "Middle",
      repeat_x = "Mirror",
      repeat_y = "NoRepeat",
      width = "Cover",
      height = "Cover",
      opacity = 1.0,
      attachment = attachment,
      hsb = { brightness = 0.12, saturation = 1.0, hue = 1.0 }, -- dim the picture
    },
  }
end

-- Pick a random image, optionally avoiding `previous` so a reshuffle changes it.
local function pick_background(previous, mode)
  mode = mode or "parallax"
  local images = list_backgrounds()
  if #images == 0 then return nil, nil end
  
  -- If we don't have a previous image (i.e., at startup), check if we have the alien spaceship background
  local file
  if not previous then
    for _, img in ipairs(images) do
      if img:find("alien_spaceship_bg") then
        file = img
        break
      end
    end
  end
  
  -- If not found or if shuffling, choose a random one
  if not file then
    file = images[math.random(#images)]
    if previous and #images > 1 then
      local guard = 0
      while file == previous and guard < 10 do
        file = images[math.random(#images)]
        guard = guard + 1
      end
    end
  end
  return background_for_mode(file, mode), file
end

-- Track the current background per window id (NOT inside config overrides --
-- WezTerm rejects unknown config keys, which would make the override fail).
local current_bg_by_window = {}

-- Helper to inspect current background mode from window overrides.
local function get_current_mode_from_overrides(window)
  local overrides = window:get_config_overrides() or {}
  if overrides.background and overrides.background[2] then
    local layer = overrides.background[2]
    if layer.attachment == "Fixed" then
      return "fixed"
    end
  end
  return "parallax"
end

-- Select a background image from a list (bound to Ctrl+a b).
local function select_background(window, pane)
  local images = list_backgrounds()
  if #images == 0 then
    window:toast_notification("WezTerm", "No background images found in\n" .. bg_dir, nil, 4000)
    return
  end

  local choices = {}
  for i, f in ipairs(images) do
    local filename = f:match("[^/\\]+$") or f
    table.insert(choices, {
      id = f,
      label = string.format("%d: %s", i, filename),
    })
  end

  window:perform_action(
    act.InputSelector({
      title = "  Select Background Image  (Esc to close, Enter to select)",
      choices = choices,
      fuzzy = true,
      fuzzy_description = "Search backgrounds: ",
      action = wezterm.action_callback(function(win, p, file, _label)
        if not file then return end -- Esc pressed
        local wid = win:window_id()
        current_bg_by_window[wid] = file
        
        local current_mode = get_current_mode_from_overrides(win)
        local bg = background_for_mode(file, current_mode)
        
        local overrides = win:get_config_overrides() or {}
        overrides.background = bg
        overrides.text_background_opacity = 1.0
        win:set_config_overrides(overrides)
        
        win:toast_notification("WezTerm", "Background: " .. (file:match("[^/\\]+$") or file), nil, 2000)
      end),
    }),
    pane
  )
end

wezterm.on("select-background", select_background)

-- Reshuffle the background of the current window (bound to Ctrl+a s).
wezterm.on("shuffle-background", function(window, _pane)
  local wid = window:window_id()
  local current_mode = get_current_mode_from_overrides(window)
  local bg, file = pick_background(current_bg_by_window[wid], current_mode)
  if not bg then
    window:toast_notification("WezTerm", "No background images found in\n" .. bg_dir, nil, 4000)
    return
  end
  current_bg_by_window[wid] = file
  local overrides = window:get_config_overrides() or {}
  overrides.background = bg
  overrides.text_background_opacity = 1.0
  window:set_config_overrides(overrides)
  window:toast_notification("WezTerm", "Background: " .. (file:match("[^/\\]+$") or file), nil, 2000)
end)

-- Toggle between parallax and fixed background modes (bound to Ctrl+a m).
wezterm.on("toggle-background-mode", function(window, _pane)
  local wid = window:window_id()
  local current_file = current_bg_by_window[wid]

  -- If we don't have a specific file tracked for this window yet, find the startup/default one
  if not current_file then
    local _, startup_file = pick_background(nil)
    current_file = startup_file
  end

  if not current_file then
    window:toast_notification("WezTerm", "No background image loaded to configure.", nil, 2000)
    return
  end

  -- Determine target mode by toggling the current overrides state
  local current_mode = get_current_mode_from_overrides(window)
  local new_mode = "parallax"
  if current_mode == "parallax" then
    new_mode = "fixed"
  end

  -- Update the background for this file in the new mode
  local bg = background_for_mode(current_file, new_mode)
  local overrides = window:get_config_overrides() or {}
  overrides.background = bg
  overrides.text_background_opacity = 1.0
  window:set_config_overrides(overrides)

  window:toast_notification("WezTerm", "Background Mode: " .. new_mode:upper(), nil, 2000)
end)

-- Initial random background at startup.
local _startup_bg = pick_background(nil)
if _startup_bg then
  config.background = _startup_bg
  config.text_background_opacity = 1.0
end
config.window_decorations = "INTEGRATED_BUTTONS | RESIZE"
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
  { keys = "Ctrl+a  b",       desc = "Select a background image from TUI menu", action = act.EmitEvent("select-background") },
  { keys = "Ctrl+a  s",       desc = "Shuffle to a new random background", action = act.EmitEvent("shuffle-background") },
  { keys = "Ctrl+a  m",       desc = "Toggle background mode (parallax/fixed)", action = act.EmitEvent("toggle-background-mode") },
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
  { key = "b", mods = "LEADER", action = act.EmitEvent("select-background") },
  { key = "s", mods = "LEADER", action = act.EmitEvent("shuffle-background") },
  { key = "m", mods = "LEADER", action = act.EmitEvent("toggle-background-mode") },
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
  -- Also allow plain Ctrl+V to paste the system clipboard (text copied from
  -- other apps/windows), so it isn't limited to the primary selection.
  { key = "v", mods = "CTRL", action = act.PasteFrom("Clipboard") },

  -- Command palette & launcher
  { key = "P", mods = "CTRL|SHIFT", action = act.ActivateCommandPalette },
  { key = "l", mods = "LEADER|CTRL", action = act.ShowLauncher },

  -- Quick-select / search
  { key = "f", mods = "CTRL|SHIFT", action = act.Search({ CaseInSensitiveString = "" }) },

  -- Cheat sheet overlay (stays up until you press a key)
  { key = "F1", action = act.EmitEvent("show-cheatsheet") },
  { key = "?", mods = "LEADER", action = act.EmitEvent("show-cheatsheet") },
}

--------------------------------------------------------------------------------
-- Mouse: copy-on-select (highlight with the mouse -> goes to the clipboard)
--------------------------------------------------------------------------------
config.mouse_bindings = {
  -- Finish a left-drag selection: copy to clipboard (and primary selection).
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = act.CompleteSelection("ClipboardAndPrimarySelection"),
  },
  -- Double-click selects a word and copies it.
  {
    event = { Up = { streak = 2, button = "Left" } },
    mods = "NONE",
    action = act.CompleteSelection("ClipboardAndPrimarySelection"),
  },
  -- Triple-click selects the whole line and copies it.
  {
    event = { Up = { streak = 3, button = "Left" } },
    mods = "NONE",
    action = act.CompleteSelection("ClipboardAndPrimarySelection"),
  },
  -- Keep Ctrl+Click as the "open hyperlink" gesture.
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = act.OpenLinkAtMouseCursor,
  },
  -- Middle-click pastes the SYSTEM clipboard (text copied from other apps),
  -- not just the X11-style primary selection.
  {
    event = { Down = { streak = 1, button = "Middle" } },
    mods = "NONE",
    action = act.PasteFrom("Clipboard"),
  },
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

