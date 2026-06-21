#!/usr/bin/env bash
#
# Full macOS bootstrap: WezTerm + Neovim/NvChad with LSP (Python/Lua/Go).
#
# Installs via Homebrew, copies the cross-platform WezTerm config and the NvChad
# config files from this repo, downloads an anime background, bootstraps plugins
# and installs LSP servers + formatters.
#
# Usage:
#   ./macos/bootstrap-full.sh                 # everything
#   SKIP_INSTALLS=1 ./macos/bootstrap-full.sh # configs only
#   NO_BACKGROUND=1 ./macos/bootstrap-full.sh # skip the image
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$REPO_ROOT/config"
source "$SCRIPT_DIR/_common.sh"

printf '\033[0;35mFull Dev Environment Bootstrap (WezTerm + Neovim) — macOS\033[0m\n'

# 1. Packages ---------------------------------------------------------------
if [ "${SKIP_INSTALLS:-0}" != "1" ]; then
  step "Installing packages via Homebrew"
  assert_brew
  brew_install_cask wezterm
  for f in neovim git ripgrep go node python; do brew_install "$f"; done
else
  step "Skipping installs (SKIP_INSTALLS=1)"
fi

NVIM_BIN="$(command -v nvim || echo /opt/homebrew/bin/nvim)"

# 2. WezTerm config ----------------------------------------------------------
step "Installing WezTerm config"
WEZ_DST="$HOME/.wezterm.lua"
backup_if_exists "$WEZ_DST"
cp "$CONFIG_DIR/wezterm/wezterm.lua" "$WEZ_DST"
ok "Wrote $WEZ_DST"

# 3. Background --------------------------------------------------------------
[ "${NO_BACKGROUND:-0}" = "1" ] && step "Skipping background (NO_BACKGROUND=1)" || get_anime_background

# 4. NvChad ------------------------------------------------------------------
step "Installing NvChad"
NVIM_CFG="$HOME/.config/nvim"
if [ ! -f "$NVIM_CFG/init.lua" ]; then
  [ -e "$NVIM_CFG" ] && mv "$NVIM_CFG" "$NVIM_CFG.bak-$TS"
  git clone https://github.com/NvChad/starter "$NVIM_CFG" >/dev/null 2>&1
  rm -rf "$NVIM_CFG/.git"
  ok "Cloned NvChad starter"
else
  ok "NvChad already present"
fi

# 5. Apply our nvim config files --------------------------------------------
step "Applying Neovim config files"
copy_nvim_config "$CONFIG_DIR" "$NVIM_CFG"
ok "Config files applied"

# 6. Plugins + LSP -----------------------------------------------------------
step "Syncing plugins (lazy.nvim)"
"$NVIM_BIN" --headless "+Lazy! sync" +qa >/dev/null 2>&1 || true
ok "Plugins synced"

step "Installing LSP servers & formatters (Mason)"
"$NVIM_BIN" --headless "+MasonInstall lua-language-server pyright gopls stylua black isort gofumpt goimports" +qa >/dev/null 2>&1 || true
MASON_BIN="$HOME/.local/share/nvim/mason/bin"
if [ -d "$MASON_BIN" ]; then ok "Mason tools installed ($(ls "$MASON_BIN" | wc -l | tr -d ' ') entries)"; else warn "Open nvim and run :Mason to finish."; fi

# 7. Verify ------------------------------------------------------------------
step "Verifying"
if command -v wezterm >/dev/null 2>&1; then
  wezterm --config-file "$WEZ_DST" show-keys >/dev/null 2>&1 && ok "WezTerm config parses cleanly" || warn "Check: wezterm --config-file $WEZ_DST show-keys"
fi
"$NVIM_BIN" --headless "+lua io.write('theme: '..require('chadrc').base46.theme)" +qa 2>&1 | grep -q 'theme:' && ok "Neovim/NvChad loads"

printf '\n\033[0;35mDone! Restart your terminal. Press F1 in WezTerm for the cheat sheet.\033[0m\n'
printf 'Tip: install the "Comic Code Ligatures" font for the intended look (falls back otherwise).\n'
