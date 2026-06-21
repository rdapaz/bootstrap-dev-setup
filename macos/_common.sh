#!/usr/bin/env bash
# Shared helpers for the macOS bootstrap scripts.

set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"

c_cyan='\033[0;36m'; c_green='\033[0;32m'; c_yellow='\033[0;33m'; c_reset='\033[0m'
step() { printf "\n${c_cyan}==> %s${c_reset}\n" "$1"; }
ok()   { printf "    ${c_green}[ok]${c_reset} %s\n" "$1"; }
warn() { printf "    ${c_yellow}[!] ${c_reset} %s\n" "$1"; }

assert_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew not found. Installing it now..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Make brew available in this session (Apple Silicon vs Intel)
    if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
    if [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
  fi
}

brew_install() {       # brew_install <formula>
  if brew list --formula "$1" >/dev/null 2>&1; then ok "$1 already installed"; return; fi
  printf "    installing %s ...\n" "$1"; brew install "$1" >/dev/null; ok "$1 installed"
}

brew_install_cask() {  # brew_install_cask <cask>
  if brew list --cask "$1" >/dev/null 2>&1; then ok "$1 already installed"; return; fi
  printf "    installing %s ...\n" "$1"; brew install --cask "$1" >/dev/null; ok "$1 installed"
}

backup_if_exists() {   # backup_if_exists <path>
  if [ -e "$1" ]; then cp -R "$1" "$1.bak-$TS"; warn "Backed up $1 -> $1.bak-$TS"; fi
}

get_anime_background() {
  step "Downloading anime background image"
  local dir="$HOME/.config/wezterm/backgrounds"
  local img="$dir/waifu.png"
  mkdir -p "$dir"
  if [ -f "$img" ]; then ok "Background already present"; return; fi
  local url
  if url="$(curl -fsSL --max-time 20 https://nekos.best/api/v2/neko | python3 -c 'import sys,json; print(json.load(sys.stdin)["results"][0]["url"])' 2>/dev/null)"; then
    if curl -fsSL --max-time 60 -o "$img" "$url"; then ok "Saved background -> $img"; else warn "Background download failed; WezTerm runs without one."; fi
  else
    warn "Could not reach nekos.best; WezTerm runs without a background."
  fi
}

copy_nvim_config() {   # copy_nvim_config <config_dir> <nvim_cfg>
  local src="$1/nvim/lua" cfg="$2"
  mkdir -p "$cfg/lua/configs" "$cfg/lua/plugins"
  backup_if_exists "$cfg/lua/chadrc.lua";            cp "$src/chadrc.lua"            "$cfg/lua/chadrc.lua"
  backup_if_exists "$cfg/lua/configs/lspconfig.lua"; cp "$src/configs/lspconfig.lua" "$cfg/lua/configs/lspconfig.lua"
  backup_if_exists "$cfg/lua/configs/conform.lua";   cp "$src/configs/conform.lua"   "$cfg/lua/configs/conform.lua"
  backup_if_exists "$cfg/lua/plugins/init.lua";      cp "$src/plugins/init.lua"      "$cfg/lua/plugins/init.lua"
}
