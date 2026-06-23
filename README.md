# bootstrap-dev-setup

One-command bootstrap for a slick **WezTerm** terminal and a **Neovim / NvChad**
development environment, for **Windows** and **macOS**.

What you get:

- 🎨 **WezTerm** — Catppuccin Mocha theme, ligature font (Comic Code, with
  fallbacks), dimmed anime background, tmux-style keybindings, and a pop-up
  **cheat-sheet overlay** (press `F1`).
- ⌨️ **Neovim + NvChad** (v2.5 starter) themed to match the terminal.
- 🧠 **LSP** for **Python** (pyright), **Lua** (lua_ls) and **Go** (gopls), with
  **format-on-save** (black/isort, stylua, gofumpt/goimports).

The WezTerm config is cross-platform — the same `config/wezterm/wezterm.lua` is
used on both OSes (Windows-only bits are guarded internally).

---

## Quick start

```bash
git clone https://github.com/rdapaz/bootstrap-dev-setup.git
cd bootstrap-dev-setup
```

### Windows (PowerShell)

```powershell
# Full setup (WezTerm + Neovim)
powershell -ExecutionPolicy Bypass -File .\windows\bootstrap-full.ps1

# WezTerm only (no Neovim)
powershell -ExecutionPolicy Bypass -File .\windows\bootstrap-wezterm-only.ps1
```

### macOS (bash/zsh)

```bash
chmod +x macos/*.sh

# Full setup (WezTerm + Neovim)
./macos/bootstrap-full.sh

# WezTerm only (no Neovim)
./macos/bootstrap-wezterm-only.sh
```

---

## Options / flags

| Goal | Windows | macOS |
|------|---------|-------|
| Skip package installs (configs only) | `-SkipInstalls` | `SKIP_INSTALLS=1` |
| Skip anime background download | `-NoBackground` | `NO_BACKGROUND=1` |
| Force-replace backgrounds + reload | `-RefreshBackgrounds` | `REFRESH_BACKGROUNDS=1` |

### Refresh backgrounds anytime

Grab a **fresh random set** of images and reload a running WezTerm:

```powershell
# Windows: replace with 7 fresh images (or -Count N, -KeepExisting to add)
powershell -ExecutionPolicy Bypass -File .\windows\refresh-backgrounds.ps1
```
```bash
# macOS: replace with 7 fresh images (or pass a count; KEEP_EXISTING=1 to add)
./macos/refresh-backgrounds.sh        # or: ./macos/refresh-backgrounds.sh 10
```

Both scripts download into `~/.config/wezterm/backgrounds` and **touch
`~/.wezterm.lua`** so an already-running WezTerm reloads and re-rolls its image
(or just press **`Ctrl+a b`** to reshuffle the current window instantly).

Example:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\bootstrap-full.ps1 -SkipInstalls -NoBackground
```
```bash
SKIP_INSTALLS=1 NO_BACKGROUND=1 ./macos/bootstrap-full.sh
```

---

## What gets installed

| Tool | Windows (winget) | macOS (brew) | Purpose |
|------|------------------|--------------|---------|
| WezTerm | `wez.wezterm` | `--cask wezterm` | terminal |
| Neovim | `Neovim.Neovim` | `neovim` | editor (full only) |
| Git | `Git.Git` | `git` | clone configs |
| ripgrep | `BurntSushi.ripgrep.MSVC` | `ripgrep` | Telescope grep |
| C compiler | `BrechtSanders.WinLibs.POSIX.UCRT` | (Xcode CLT) | treesitter parsers |
| Go | `GoLang.Go` | `go` | `gopls` |
| Node.js | `OpenJS.NodeJS` | `node` | `pyright` |
| Python | `Python.Python.3.14` | `python` | black/isort |

> The **Comic Code Ligatures** font is commercial and must be installed
> manually. Without it the config falls back to JetBrains Mono → Cascadia → Consolas.

---

## Repository layout

```
bootstrap-dev-setup/
├── README.md
├── config/                     # the actual configs (single source of truth)
│   ├── wezterm/wezterm.lua      # cross-platform WezTerm config
│   └── nvim/lua/                # NvChad overrides
│       ├── chadrc.lua           #   theme = catppuccin
│       ├── configs/lspconfig.lua#   pyright / lua_ls / gopls
│       ├── configs/conform.lua  #   formatters + format-on-save
│       └── plugins/init.lua     #   Mason ensure_installed, treesitter
├── windows/
│   ├── bootstrap-full.ps1
│   ├── bootstrap-wezterm-only.ps1
│   └── _common.ps1              # shared helpers
├── macos/
│   ├── bootstrap-full.sh
│   ├── bootstrap-wezterm-only.sh
│   └── _common.sh               # shared helpers
└── docs/
    └── setup-spec.md            # detailed, manual step-by-step spec
```

The bootstrap scripts simply copy files out of `config/` into their OS-specific
locations, so **editing a config once in `config/` keeps every script in sync**.

---

## Config locations (after running)

| Item | Windows | macOS |
|------|---------|-------|
| WezTerm config | `%USERPROFILE%\.wezterm.lua` | `~/.wezterm.lua` |
| Background image | `%USERPROFILE%\.config\wezterm\backgrounds\waifu.png` | `~/.config/wezterm/backgrounds/waifu.png` |
| Neovim config | `%LOCALAPPDATA%\nvim` | `~/.config/nvim` |
| Neovim data/plugins | `%LOCALAPPDATA%\nvim-data` | `~/.local/share/nvim` |

Existing files are backed up with a `.bak-<timestamp>` suffix before being
overwritten, so the scripts are safe to re-run.

---

## Keybinding cheat sheets

**WezTerm** (leader = `Ctrl+a`): press **`F1`** or **`Ctrl+a ?`** in the terminal
for a searchable overlay. Highlights: `\`/`-` split, `h/j/k/l` move panes,
`c`/`n`/`p`/`1-9` tabs, `Ctrl+Shift+P` palette.

**Neovim / NvChad** (leader = `Space`): `Space th` themes, `Space ff` find files,
`Space fw` grep, `Ctrl+n` file tree, `Space ch` cheatsheet, `K`/`gd`/`gr`
hover/def/refs, `:Mason` manage tools.

See [`docs/setup-spec.md`](docs/setup-spec.md) for the full manual walkthrough.

---

## Optional: LLM integration (add-on)

A self-contained add-on under [`features/llm-integration/`](features/llm-integration/)
wires a small multi-provider (Anthropic / OpenAI / Google) Python REPL into
WezTerm. It is **not** part of `bootstrap-full` — install it only when you want
it, remove it cleanly when you don’t.

- `LEADER + i` opens the REPL in a new tab
- `LEADER + Shift + I` opens it as a right split

The installer creates a dedicated venv (`~/.venv/wezterm-llm`), installs the
`anthropic`, `openai`, and `google-generativeai` clients, deploys a sidecar
Lua module to `~/.config/wezterm/llm-integration.lua`, and adds a single
marked block to `~/.wezterm.lua` that `require`s it. Both install and
uninstall are **idempotent** — safe to re-run.

### Install

**Windows (PowerShell):**

```powershell
powershell -ExecutionPolicy Bypass -File .\features\llm-integration\install.ps1
```

**macOS / Linux / WSL (bash):**

```bash
chmod +x features/llm-integration/install.sh
./features/llm-integration/install.sh
```

Then set **one** of the following env vars (first match wins, in this order:
Anthropic → OpenAI → Google):

```powershell
# Windows (persistent, User scope)
[Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY","sk-ant-...","User")
[Environment]::SetEnvironmentVariable("OPENAI_API_KEY","sk-...","User")
[Environment]::SetEnvironmentVariable("GOOGLE_API_KEY","AIza...","User")
```

```bash
# macOS / Linux — add to ~/.zshrc or ~/.bashrc
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
export GOOGLE_API_KEY="AIza..."
```

Optional overrides: `LLM_PROVIDER=anthropic|openai|google`, `LLM_MODEL=<name>`.
Restart WezTerm and press `LEADER + i`.

### Uninstall

**Windows:**

```powershell
powershell -ExecutionPolicy Bypass -File .\features\llm-integration\uninstall.ps1
# keep the venv: add  -KeepVenv
```

**macOS / Linux / WSL:**

```bash
./features/llm-integration/uninstall.sh
# keep the venv: KEEP_VENV=1 ./features/llm-integration/uninstall.sh
```

The uninstaller strips only the marked block from `~/.wezterm.lua` (taking a
timestamped `.bak` first), removes the sidecar, the REPL, and the venv. API
key env vars are never touched.

See [`features/llm-integration/README.md`](features/llm-integration/README.md)
for details.

---

## Credits

- [WezTerm](https://wezfurlong.org/wezterm/) · [NvChad](https://nvchad.com/) ·
  [Catppuccin](https://github.com/catppuccin).
- The repo ships **7 pinned** WezTerm backgrounds at
  `config/wezterm/backgrounds/waifu-*.png`; the scripts install all of them and
  `wezterm.lua` displays **one at random each launch**. If the folder is empty,
  the scripts fall back to downloading 7 random SFW images from
  [nekos.best](https://nekos.best) (artist-credited art). Add or replace images
  in that folder to customise the rotation.
