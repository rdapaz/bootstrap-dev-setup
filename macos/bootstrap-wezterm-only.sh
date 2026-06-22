#!/usr/bin/env bash
#
# macOS bootstrap: WezTerm only (no Neovim).
#
# Installs WezTerm via Homebrew, copies the cross-platform WezTerm config, and
# downloads an anime background. Does NOT install or touch Neovim.
#
# Usage:
#   ./macos/bootstrap-wezterm-only.sh
#   SKIP_INSTALLS=1 ./macos/bootstrap-wezterm-only.sh
#   NO_BACKGROUND=1 ./macos/bootstrap-wezterm-only.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$REPO_ROOT/config"
source "$SCRIPT_DIR/_common.sh"

printf '\033[0;35mWezTerm Bootstrap (terminal only) — macOS\033[0m\n'

# 1. Packages ---------------------------------------------------------------
if [ "${SKIP_INSTALLS:-0}" != "1" ]; then
  step "Installing WezTerm via Homebrew"
  assert_brew
  brew_install_cask wezterm
else
  step "Skipping installs (SKIP_INSTALLS=1)"
fi

# 2. WezTerm config ----------------------------------------------------------
step "Installing WezTerm config"
WEZ_DST="$HOME/.wezterm.lua"
backup_if_exists "$WEZ_DST"
cp "$CONFIG_DIR/wezterm/wezterm.lua" "$WEZ_DST"
ok "Wrote $WEZ_DST"

# 3. Background --------------------------------------------------------------
[ "${NO_BACKGROUND:-0}" = "1" ] && step "Skipping background (NO_BACKGROUND=1)" || get_anime_background "$CONFIG_DIR/wezterm/backgrounds"

# 4. Verify ------------------------------------------------------------------
step "Verifying"
if command -v wezterm >/dev/null 2>&1; then
  wezterm --config-file "$WEZ_DST" show-keys >/dev/null 2>&1 && ok "WezTerm config parses cleanly" || warn "Check: wezterm --config-file $WEZ_DST show-keys"
else
  warn "wezterm not found on PATH yet; restart the shell."
fi

printf '\n\033[0;35mDone! Restart your terminal and launch WezTerm. Press F1 for the cheat sheet.\033[0m\n'
printf 'Tip: install the "Comic Code Ligatures" font for the intended look (falls back otherwise).\n'
