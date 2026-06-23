#!/usr/bin/env bash
# Install WezTerm LLM integration. Idempotent. Pairs with uninstall.sh.
set -euo pipefail

WEZTERM_CONFIG="${WEZTERM_CONFIG:-$HOME/.wezterm.lua}"
VENV_DIR="${VENV_DIR:-$HOME/.venv/wezterm-llm}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
WEZ_CONFIG_DIR="${WEZ_CONFIG_DIR:-$HOME/.config/wezterm}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEGIN_MARKER="-- >>> bootstrap-dev-setup: llm-integration >>>"
END_MARKER="-- <<< bootstrap-dev-setup: llm-integration <<<"

step() { printf '\033[36m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\033[31m!! %s\033[0m\n' "$*" >&2; exit 1; }

# --- 1. Python ---------------------------------------------------------------
step "Locating Python"
PYTHON_BIN="$(command -v python3 || command -v python || true)"
[[ -n "$PYTHON_BIN" ]] || die "python3 not found in PATH"
info "Using $PYTHON_BIN"

# --- 2. Venv -----------------------------------------------------------------
VENV_PY="$VENV_DIR/bin/python"
if [[ ! -x "$VENV_PY" ]]; then
  step "Creating venv at $VENV_DIR"
  "$PYTHON_BIN" -m venv "$VENV_DIR"
else
  step "Venv already exists at $VENV_DIR"
fi

step "Installing/updating Python packages"
"$VENV_PY" -m pip install --quiet --upgrade pip
"$VENV_PY" -m pip install --quiet --upgrade anthropic openai google-generativeai

# --- 3. Deploy llm-client.py -------------------------------------------------
step "Deploying llm-client.py -> $BIN_DIR"
mkdir -p "$BIN_DIR"
CLIENT_DST="$BIN_DIR/llm-client.py"
install -m 0755 "$HERE/llm-client.py" "$CLIENT_DST"
info "$CLIENT_DST"

# --- 4. Deploy sidecar lua with paths baked in -------------------------------
step "Deploying llm-integration.lua -> $WEZ_CONFIG_DIR"
mkdir -p "$WEZ_CONFIG_DIR"
LUA_DST="$WEZ_CONFIG_DIR/llm-integration.lua"
# escape for sed replacement (slashes -> \/)
esc_py=$(printf '%s' "$VENV_PY"   | sed 's/[\/&]/\\&/g')
esc_sc=$(printf '%s' "$CLIENT_DST" | sed 's/[\/&]/\\&/g')
sed \
  -e "s/local PYTHON = getenv_or('WEZTERM_LLM_PYTHON', 'python')/local PYTHON = getenv_or('WEZTERM_LLM_PYTHON', '$esc_py')/" \
  -e "s/local SCRIPT = getenv_or('WEZTERM_LLM_SCRIPT', '')/local SCRIPT = getenv_or('WEZTERM_LLM_SCRIPT', '$esc_sc')/" \
  "$HERE/llm-integration.lua" > "$LUA_DST"
info "$LUA_DST"

# --- 5. Patch ~/.wezterm.lua (marked block, idempotent) ----------------------
[[ -f "$WEZTERM_CONFIG" ]] || die "WezTerm config not found at $WEZTERM_CONFIG. Run the main bootstrap first."

step "Patching $WEZTERM_CONFIG"
if grep -qF "$BEGIN_MARKER" "$WEZTERM_CONFIG"; then
  info "Marker already present; skipping (run uninstall.sh first to refresh)."
else
  backup="$WEZTERM_CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$WEZTERM_CONFIG" "$backup"
  info "Backed up to $backup"

  block=$(cat <<EOF

$BEGIN_MARKER
do
  local ok, llm = pcall(function()
    package.path = package.path .. ';$WEZ_CONFIG_DIR/?.lua'
    return require('llm-integration')
  end)
  if ok and llm and llm.apply then llm.apply(config) end
end
$END_MARKER
EOF
)

  # Try to insert before a trailing `return config`; otherwise append.
  if grep -qE '^[[:space:]]*return[[:space:]]+config[[:space:]]*$' "$WEZTERM_CONFIG"; then
    tmp="$(mktemp)"
    awk -v block="$block" '
      /^[[:space:]]*return[[:space:]]+config[[:space:]]*$/ && !done { print block; done=1 }
      { print }
    ' "$WEZTERM_CONFIG" > "$tmp"
    mv "$tmp" "$WEZTERM_CONFIG"
  else
    printf '\n%s\n' "$block" >> "$WEZTERM_CONFIG"
  fi
  info "Added marked block."
fi

cat <<'EOF'

Done.
Set ONE of these env vars in your shell profile (~/.zshrc, ~/.bashrc):
  export ANTHROPIC_API_KEY="sk-ant-..."
  export OPENAI_API_KEY="sk-..."
  export GOOGLE_API_KEY="AIza..."
Then restart WezTerm and press LEADER + i (split with LEADER + Shift + I).
EOF
