-- llm-integration.lua
-- Sidecar WezTerm module installed by features/llm-integration.
-- Loaded from ~/.wezterm.lua via the marked block added by install scripts.
--
-- Reads its config from environment variables that the install scripts set
-- (or you can edit this file directly):
--   WEZTERM_LLM_PYTHON  -> absolute path to the venv python
--   WEZTERM_LLM_SCRIPT  -> absolute path to llm-client.py

local wezterm = require 'wezterm'

local M = {}

local function getenv_or(name, fallback)
  local v = os.getenv(name)
  if v == nil or v == '' then return fallback end
  return v
end

-- These defaults are overwritten by the install script (sed/Set-Content) so
-- the deployed copy at ~/.config/wezterm/llm-integration.lua has concrete paths.
local PYTHON = getenv_or('WEZTERM_LLM_PYTHON', 'python')
local SCRIPT = getenv_or('WEZTERM_LLM_SCRIPT', '')

function M.apply(config)
  config.keys = config.keys or {}

  table.insert(config.keys, {
    key = 'i',
    mods = 'LEADER',
    action = wezterm.action.SpawnCommandInNewTab {
      args = { PYTHON, SCRIPT },
    },
  })

  table.insert(config.keys, {
    key = 'I',
    mods = 'LEADER|SHIFT',
    action = wezterm.action.SplitPane {
      direction = 'Right',
      command = { args = { PYTHON, SCRIPT } },
      size = { Percent = 40 },
    },
  })
end

return M
