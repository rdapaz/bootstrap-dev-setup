# features/llm-integration

Optional add-on for `bootstrap-dev-setup`. Adds a WezTerm keybinding that
spawns a small Python REPL talking to one of:

- **Anthropic** (`ANTHROPIC_API_KEY`, default model `claude-3-5-sonnet-latest`)
- **OpenAI**    (`OPENAI_API_KEY`, default model `gpt-4o-mini`)
- **Google**    (`GOOGLE_API_KEY`, default model `gemini-1.5-flash`)

The first available key wins, in that order. Override with
`LLM_PROVIDER=anthropic|openai|google` and/or `LLM_MODEL=<name>`.

Inspired by:
https://bedecarroll.com/2025/07/05/talking-to-ai-from-your-terminal-wezterm-llm/

## What gets installed

| Path                                         | What                       |
|----------------------------------------------|----------------------------|
| `~/.venv/wezterm-llm/`                       | Dedicated Python venv      |
| `~/.local/bin/llm-client.py`                 | The REPL (Win: same path under `$HOME`) |
| `~/.config/wezterm/llm-integration.lua`      | WezTerm sidecar module     |
| Marked block in `~/.wezterm.lua`             | `require`s the sidecar     |

## Keys

- `LEADER + i` — open the LLM REPL in a new tab
- `LEADER + Shift + I` — open it in a right split (40%)

WezTerm `LEADER` in this repo is `Ctrl+a`.

## Install / Uninstall

See the top-level README "Optional: LLM integration" section.

## Idempotency

- Re-running `install` is safe; it skips work that's already done.
- The patch to `~/.wezterm.lua` is wrapped in unique markers
  (`-- >>> bootstrap-dev-setup: llm-integration >>>` / `<<<`).
- `uninstall` removes exactly that block, the sidecar, the REPL, and the venv.
  API key env vars are never touched.
