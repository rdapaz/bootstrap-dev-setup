#!/usr/bin/env bash
#
# Download a fresh set of random WezTerm background images.
#
# Replaces the images in ~/.config/wezterm/backgrounds with COUNT freshly
# downloaded random SFW anime images from nekos.best, then touches
# ~/.wezterm.lua so a running WezTerm reloads and re-rolls its background.
#
# Usage:
#   ./macos/refresh-backgrounds.sh            # 7 fresh images (replace)
#   ./macos/refresh-backgrounds.sh 10         # 10 fresh images
#   KEEP_EXISTING=1 ./macos/refresh-backgrounds.sh 3   # add 3, keep current
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

COUNT="${1:-7}"
printf '\033[0;35mRefresh WezTerm backgrounds\033[0m\n'

dir="$(wezterm_bg_dir)"
if [ "${KEEP_EXISTING:-0}" != "1" ]; then
  rm -f "$dir"/*.png "$dir"/*.jpg "$dir"/*.jpeg "$dir"/*.webp 2>/dev/null || true
  warn "Removed existing image(s)"
fi

step "Downloading $COUNT fresh image(s)"
get_random_backgrounds "$COUNT"
touch_wezterm_config

printf '\n\033[0;35mDone. A running WezTerm will reload; or press Ctrl+a b to reshuffle now.\033[0m\n'
