#!/usr/bin/env bash
# Remove WezTerm LLM integration. Idempotent. Pairs with install.sh.
set -euo pipefail

WEZTERM_CONFIG="${WEZTERM_CONFIG:-$HOME/.wezterm.lua}"
VENV_DIR="${VENV_DIR:-$HOME/.venv/wezterm-llm}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
WEZ_CONFIG_DIR="${WEZ_CONFIG_DIR:-$HOME/.config/wezterm}"
KEEP_VENV="${KEEP_VENV:-0}"

BEGIN_MARKER="-- >>> bootstrap-dev-setup: llm-integration >>>"
END_MARKER="-- <<< bootstrap-dev-setup: llm-integration <<<"

step() { printf '\033[36m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }

# --- 1. Strip marked block ---------------------------------------------------
if [[ -f "$WEZTERM_CONFIG" ]]; then
  step "Stripping marked block from $WEZTERM_CONFIG"
  if grep -qF "$BEGIN_MARKER" "$WEZTERM_CONFIG"; then
    backup="$WEZTERM_CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$WEZTERM_CONFIG" "$backup"
    info "Backed up to $backup"
    awk -v b="$BEGIN_MARKER" -v e="$END_MARKER" '
      index($0,b){ skip=1 }
      !skip
      index($0,e){ skip=0; next }
    ' "$WEZTERM_CONFIG" > "$WEZTERM_CONFIG.tmp"
    mv "$WEZTERM_CONFIG.tmp" "$WEZTERM_CONFIG"
    info "Removed."
  else
    info "Marker not found; nothing to remove."
  fi
else
  info "$WEZTERM_CONFIG not found; skipping."
fi

# --- 2. Remove deployed files ------------------------------------------------
for p in "$WEZ_CONFIG_DIR/llm-integration.lua" "$BIN_DIR/llm-client.py"; do
  if [[ -e "$p" ]]; then
    step "Removing $p"
    rm -f "$p"
  else
    info "Already absent: $p"
  fi
done

# --- 3. Remove venv ----------------------------------------------------------
if [[ "$KEEP_VENV" = "1" ]]; then
  info "Keeping venv at $VENV_DIR (KEEP_VENV=1)."
elif [[ -d "$VENV_DIR" ]]; then
  step "Removing venv $VENV_DIR"
  rm -rf "$VENV_DIR"
else
  info "Venv already absent: $VENV_DIR"
fi

echo
echo "Uninstall complete."
echo "API keys (ANTHROPIC_API_KEY / OPENAI_API_KEY / GOOGLE_API_KEY) were NOT touched."
