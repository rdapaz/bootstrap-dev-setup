# Terminal & Dev Environment Setup Specification

A complete, reproducible specification of a Windows terminal + Neovim development
environment built around **WezTerm** and **NvChad**.

> **Target platform:** Windows 10/11
> **Shells used:** PowerShell (default), Git Bash (for the commands below)
> **Created:** 2026-06-21

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [WezTerm Configuration](#3-wezterm-configuration)
   - 3.1 [Base config & theme](#31-base-config--theme)
   - 3.2 [Font: Comic Code Ligatures](#32-font-comic-code-ligatures)
   - 3.3 [Anime background image](#33-anime-background-image)
   - 3.4 [Keybindings (tmux-style leader)](#34-keybindings-tmux-style-leader)
   - 3.5 [Cheat-sheet overlay](#35-cheat-sheet-overlay)
   - 3.6 [Full `.wezterm.lua`](#36-full-weztermlua)
4. [Neovim + NvChad](#4-neovim--nvchad)
   - 4.1 [Install Neovim & deps](#41-install-neovim--dependencies)
   - 4.2 [Install NvChad](#42-install-nvchad-starter)
   - 4.3 [Theme to match WezTerm](#43-match-theme-to-wezterm)
   - 4.4 [LSP servers: Python, Lua, Go](#44-lsp-servers-python-lua-go)
   - 4.5 [Formatters & format-on-save](#45-formatters--format-on-save)
5. [File Locations Reference](#5-file-locations-reference)
6. [Verification Checklist](#6-verification-checklist)
7. [Daily-Use Keybinding Reference](#7-daily-use-keybinding-reference)

---

## 1. Overview

This setup produces:

- A **pimped-up WezTerm** terminal: Catppuccin Mocha theme, ligature font,
  dimmed anime background, tmux-style keybindings, and a pop-up cheat-sheet overlay.
- **Neovim** managed by **NvChad** (v2.5 starter), themed to match the terminal.
- Working **LSP** for **Python, Lua, and Go**, plus **format-on-save**.

Everything is installed via `winget` and `git`, so it is fully scriptable.

---

## 2. Prerequisites

Install these first (most via `winget`). Verify each is on `PATH` (restart the
shell after installing).

| Tool | winget ID | Why |
|------|-----------|-----|
| WezTerm | `wez.wezterm` | the terminal |
| Git | `Git.Git` | clone configs, used by lazy.nvim |
| Neovim | `Neovim.Neovim` | the editor (0.10+ required for NvChad) |
| ripgrep | `BurntSushi.ripgrep.MSVC` | Telescope live-grep |
| A C compiler (gcc) | `BrechtSanders.WinLibs.POSIX.UCRT` | compiles treesitter parsers |
| Go | `GoLang.Go` | required by `gopls` |
| Node.js | `OpenJS.NodeJS` | required by `pyright` |
| Python | `Python.Python.3.14` | required by `black`/`isort`/pyright runtime |

Example install commands (PowerShell or Git Bash):

```bash
winget install --id wez.wezterm -e --accept-source-agreements --accept-package-agreements
winget install --id Git.Git -e
winget install --id Neovim.Neovim -e
winget install --id BurntSushi.ripgrep.MSVC -e
winget install --id BrechtSanders.WinLibs.POSIX.UCRT -e
winget install --id GoLang.Go -e
winget install --id OpenJS.NodeJS -e
winget install --id Python.Python.3.14 -e
```

A **Nerd Font** is recommended for icons (e.g. `JetBrainsMono Nerd Font`). The
terminal font used here is **Comic Code Ligatures** (a commercial font; install
the `.otf` into `C:\Windows\Fonts`).

---

## 3. WezTerm Configuration

WezTerm reads `~/.wezterm.lua` (i.e. `C:\Users\<you>\.wezterm.lua`).

### 3.1 Base config & theme

- Color scheme: **Catppuccin Mocha**
- 96% window opacity, slim padding, resize-only window decorations
- Blinking bar cursor, WebGpu front-end, 10k scrollback
- Custom tab titles (`1: title`) + clock in the right status bar

### 3.2 Font: Comic Code Ligatures

Primary font with sensible fallbacks. Ligatures enabled via `harfbuzz_features`.

```lua
config.font = wezterm.font_with_fallback({
  "Comic Code Ligatures",
  "JetBrainsMono Nerd Font",
  "JetBrains Mono",
  "Cascadia Code",
  "Consolas",
})
config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }
```

Verify the font resolves:

```bash
"/c/Program Files/WezTerm/wezterm.exe" --config-file ~/.wezterm.lua ls-fonts | head
```

### 3.3 Anime background image

A SFW anime image is downloaded from **nekos.best** (artist-credited art) and
used as a dimmed, full-cover background so text stays readable.

```bash
mkdir -p ~/.config/wezterm/backgrounds
# Fetch a random image URL from the API, then download it:
url=$(curl -s "https://nekos.best/api/v2/neko" \
  | python -c "import sys,json; print(json.load(sys.stdin)['results'][0]['url'])")
curl -s -o ~/.config/wezterm/backgrounds/waifu.png "$url"
```

Background config (layered: solid base color + dimmed image):

```lua
config.background = {
  { source = { Color = "#1e1e2e" }, width = "100%", height = "100%" },
  {
    source = { File = wezterm.home_dir .. "/.config/wezterm/backgrounds/waifu.png" },
    horizontal_align = "Right",
    vertical_align = "Middle",
    repeat_x = "NoRepeat", repeat_y = "NoRepeat",
    width = "Cover", height = "Cover",
    opacity = 1.0,
    hsb = { brightness = 0.12, saturation = 1.0, hue = 1.0 }, -- dim the image
  },
}
config.text_background_opacity = 1.0
```

> Tune `brightness` (e.g. `0.2` for brighter). Switch `width/height` from
> `"Cover"` to `"Contain"` to anchor the character to the right instead of filling.

### 3.4 Keybindings (tmux-style leader)

Leader = **`Ctrl+a`**. Highlights:

- `Ctrl+a \` / `Ctrl+a -` — split horizontal / vertical
- `Ctrl+a h/j/k/l` — move between panes
- `Ctrl+a z` zoom, `Ctrl+a x` close pane
- `Ctrl+a c` new tab, `n`/`p` next/prev, `1-9` jump to tab
- `Ctrl+= / - / 0` — font size up/down/reset
- `Ctrl+Shift+C/V` copy/paste, `Ctrl+Shift+P` command palette, `Ctrl+Shift+F` search

### 3.5 Cheat-sheet overlay

A pop-up, fuzzy-searchable list of keybindings that **stays up until a key is
pressed** (Esc to close, Enter to *run* the selected action). Implemented with
WezTerm's native `InputSelector`. Triggered by **`F1`** or **`Ctrl+a ?`**.

### 3.6 Full `.wezterm.lua`

Save the following as `C:\Users\<you>\.wezterm.lua`:

```lua
-- ~/.wezterm.lua
-- A pimped-up WezTerm config
local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- Appearance / Theme ---------------------------------------------------------
config.color_scheme = "Catppuccin Mocha"

config.font = wezterm.font_with_fallback({
  "Comic Code Ligatures",
  "JetBrainsMono Nerd Font",
  "JetBrains Mono",
  "Cascadia Code",
  "Consolas",
})
config.font_size = 11.0
config.line_height = 1.05
config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }

config.window_background_opacity = 0.96
config.macos_window_background_blur = 20
config.window_decorations = "RESIZE"
config.window_padding = { left = 12, right = 12, top = 10, bottom = 8 }
config.initial_cols = 120
config.initial_rows = 32
config.adjust_window_size_when_changing_font_size = false

-- Anime background -----------------------------------------------------------
config.background = {
  { source = { Color = "#1e1e2e" }, width = "100%", height = "100%" },
  {
    source = { File = wezterm.home_dir .. "/.config/wezterm/backgrounds/waifu.png" },
    horizontal_align = "Right",
    vertical_align = "Middle",
    repeat_x = "NoRepeat",
    repeat_y = "NoRepeat",
    width = "Cover",
    height = "Cover",
    opacity = 1.0,
    hsb = { brightness = 0.12, saturation = 1.0, hue = 1.0 },
  },
}
config.text_background_opacity = 1.0

-- Cursor / scrollback --------------------------------------------------------
config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"
config.scrollback_lines = 10000
config.enable_scroll_bar = false

-- Tab bar --------------------------------------------------------------------
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false
config.tab_max_width = 28
config.show_new_tab_button_in_tab_bar = true

wezterm.on("format-tab-title", function(tab, _tabs, _panes, _config, _hover, max_width)
  local title = tab.tab_title
  if not title or #title == 0 then
    title = tab.active_pane.title
  end
  title = wezterm.truncate_right(title, max_width - 6)
  local idx = tab.tab_index + 1
  return { { Text = "  " .. idx .. ": " .. title .. "  " } }
end)

wezterm.on("update-right-status", function(window, _pane)
  local date = wezterm.strftime("%a %b %-d  %H:%M")
  window:set_right_status(wezterm.format({
    { Foreground = { Color = "#89b4fa" } },
    { Text = " " .. date .. "  " },
  }))
end)

-- Default shell (Windows) ----------------------------------------------------
if wezterm.target_triple:find("windows") then
  config.default_prog = { "powershell.exe", "-NoLogo" }
  config.launch_menu = {
    { label = "PowerShell", args = { "powershell.exe", "-NoLogo" } },
    { label = "Command Prompt", args = { "cmd.exe" } },
    { label = "Git Bash", args = { "C:\\Program Files\\Git\\bin\\bash.exe", "-i", "-l" } },
  }
end

-- Cheat sheet overlay --------------------------------------------------------
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
        if not id then return end
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

-- Keybindings ----------------------------------------------------------------
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
  { key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
  { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
  { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
  { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
  { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
  { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
  { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
  { key = "=", mods = "CTRL", action = act.IncreaseFontSize },
  { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
  { key = "0", mods = "CTRL", action = act.ResetFontSize },
  { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
  { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },
  { key = "P", mods = "CTRL|SHIFT", action = act.ActivateCommandPalette },
  { key = "l", mods = "LEADER|CTRL", action = act.ShowLauncher },
  { key = "f", mods = "CTRL|SHIFT", action = act.Search({ CaseInSensitiveString = "" }) },
  { key = "F1", action = act.EmitEvent("show-cheatsheet") },
  { key = "?", mods = "LEADER", action = act.EmitEvent("show-cheatsheet") },
}

for i = 1, 9 do
  table.insert(config.keys, {
    key = tostring(i), mods = "LEADER", action = act.ActivateTab(i - 1),
  })
end

-- Misc -----------------------------------------------------------------------
config.audible_bell = "Disabled"
config.window_close_confirmation = "NeverPrompt"
config.front_end = "WebGpu"
config.animation_fps = 60
config.max_fps = 120

return config
```

Validate the config without opening a window:

```bash
"/c/Program Files/WezTerm/wezterm.exe" --config-file ~/.wezterm.lua show-keys | head
```

---

## 4. Neovim + NvChad

### 4.1 Install Neovim & dependencies

```bash
winget install --id Neovim.Neovim -e
winget install --id BurntSushi.ripgrep.MSVC -e
# C compiler for treesitter (if not already present):
winget install --id BrechtSanders.WinLibs.POSIX.UCRT -e
```

Neovim installs to `C:\Program Files\Neovim\bin\nvim.exe`.

### 4.2 Install NvChad (starter)

```bash
cd ~/AppData/Local
git clone https://github.com/NvChad/starter nvim
rm -rf nvim/.git          # make the config your own
```

Bootstrap all plugins headlessly (clones lazy.nvim and installs everything):

```bash
"/c/Program Files/Neovim/bin/nvim.exe" --headless "+Lazy! sync" +qa
```

### 4.3 Match theme to WezTerm

Edit `~/AppData/Local/nvim/lua/chadrc.lua`:

```lua
---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "catppuccin", -- matches WezTerm Catppuccin Mocha
  hl_override = {
    Comment = { italic = true },
    ["@comment"] = { italic = true },
  },
}

M.nvdash = { load_on_startup = true } -- startup dashboard

return M
```

### 4.4 LSP servers: Python, Lua, Go

**Prerequisites:** Go (`gopls`), Node.js (`pyright`), Python (runtime).

Edit `~/AppData/Local/nvim/lua/configs/lspconfig.lua`:

```lua
require("nvchad.configs.lspconfig").defaults()

-- Servers that work with default settings
local servers = { "html", "cssls", "pyright", "gopls" }
vim.lsp.enable(servers)

-- Lua LS: make it aware of the Neovim runtime + `vim` global
vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } },
      workspace = {
        library = {
          vim.fn.expand("$VIMRUNTIME/lua"),
          vim.fn.stdpath("data") .. "/lazy",
        },
        checkThirdParty = false,
      },
      telemetry = { enable = false },
    },
  },
})
vim.lsp.enable("lua_ls")

-- gopls: enable common analyses + staticcheck
vim.lsp.config("gopls", {
  settings = {
    gopls = {
      analyses = { unusedparams = true, shadow = true },
      staticcheck = true,
      gofumpt = true,
    },
  },
})
```

Add Mason auto-install + treesitter parsers in
`~/AppData/Local/nvim/lua/plugins/init.lua`:

```lua
return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre", -- format on save
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- Auto-install LSP servers, formatters & linters via Mason
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "lua-language-server",
        "pyright",
        "gopls",
        "stylua",
        "black",
        "isort",
        "gofumpt",
        "goimports",
      },
    },
  },

  -- Treesitter parsers
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "lua", "luadoc", "vim", "vimdoc",
        "python", "go", "gomod", "gosum",
      },
    },
  },
}
```

Sync the new specs and install the tools:

```bash
# Put go/node/gcc on PATH for the headless run if needed, then:
"/c/Program Files/Neovim/bin/nvim.exe" --headless "+Lazy! sync" +qa
"/c/Program Files/Neovim/bin/nvim.exe" --headless \
  "+MasonInstall lua-language-server pyright gopls stylua black isort gofumpt goimports" +qa
```

### 4.5 Formatters & format-on-save

Edit `~/AppData/Local/nvim/lua/configs/conform.lua`:

```lua
local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "isort", "black" },
    go = { "goimports", "gofumpt" },
  },

  format_on_save = {
    timeout_ms = 500,
    lsp_fallback = true,
  },
}

return options
```

---

## 5. File Locations Reference

| Item | Path |
|------|------|
| WezTerm config | `C:\Users\<you>\.wezterm.lua` |
| WezTerm background image | `C:\Users\<you>\.config\wezterm\backgrounds\waifu.png` |
| Neovim config root | `C:\Users\<you>\AppData\Local\nvim\` |
| - NvChad theme/UI | `...\nvim\lua\chadrc.lua` |
| - Plugin specs | `...\nvim\lua\plugins\init.lua` |
| - LSP config | `...\nvim\lua\configs\lspconfig.lua` |
| - Formatter config | `...\nvim\lua\configs\conform.lua` |
| Neovim plugin data | `C:\Users\<you>\AppData\Local\nvim-data\lazy\` |
| Mason tools | `C:\Users\<you>\AppData\Local\nvim-data\mason\` |
| Neovim binary | `C:\Program Files\Neovim\bin\nvim.exe` |

---

## 6. Verification Checklist

```bash
# WezTerm config parses & font resolves
"/c/Program Files/WezTerm/wezterm.exe" --config-file ~/.wezterm.lua show-keys | head
"/c/Program Files/WezTerm/wezterm.exe" --config-file ~/.wezterm.lua ls-fonts | head

# Neovim / NvChad loads & theme applied
"/c/Program Files/Neovim/bin/nvim.exe" --headless \
  "+lua print('theme: '..require('chadrc').base46.theme)" +qa

# Mason tools present
ls ~/AppData/Local/nvim-data/mason/bin/
```

Inside Neovim:

- `:checkhealth lsp` — confirm pyright / lua_ls / gopls attach
- `:Mason` — verify all 8 tools show as installed
- Open a `.py`, `.lua`, `.go` file — LSP attaches; save triggers formatting

---

## 7. Daily-Use Keybinding Reference

### WezTerm (leader = `Ctrl+a`)

| Keys | Action |
|------|--------|
| `F1` or `Ctrl+a ?` | Cheat-sheet overlay |
| `Ctrl+a \` / `-` | Split horizontal / vertical |
| `Ctrl+a h/j/k/l` | Move between panes |
| `Ctrl+a z` / `x` | Zoom / close pane |
| `Ctrl+a c` / `n` / `p` | New / next / prev tab |
| `Ctrl+a 1-9` | Jump to tab N |
| `Ctrl+= / - / 0` | Font size up / down / reset |
| `Ctrl+Shift+C / V` | Copy / paste |
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+Shift+F` | Search scrollback |

### Neovim / NvChad (leader = `Space`)

| Keys | Action |
|------|--------|
| `Space th` | Theme switcher |
| `Space ff` / `Space fw` | Find files / live grep |
| `Ctrl+n` / `Space e` | Toggle / focus file tree |
| `Space ch` | NvChad cheatsheet |
| `K` / `gd` / `gr` | Hover / go-to-def / references |
| `Space ra` / `Space ca` | Rename / code action |
| `Space x` | Close buffer |
| `:Mason` | Manage LSP/formatters |

---

*End of specification.*
