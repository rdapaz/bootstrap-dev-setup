#!/usr/bin/env python3
"""Minimal multi-provider LLM REPL for WezTerm.

Picks the first available provider based on env vars, in this order:
  1. ANTHROPIC_API_KEY  -> Anthropic (claude-3-5-sonnet-latest)
  2. OPENAI_API_KEY     -> OpenAI    (gpt-4o-mini)
  3. GOOGLE_API_KEY     -> Google    (gemini-1.5-flash)

Override the provider with LLM_PROVIDER=anthropic|openai|google.
Override the model with  LLM_MODEL=<model-name>.

Reads prompts from stdin line-by-line (interactive REPL). End an input with a
blank line to send. Ctrl+C or Ctrl+D to exit.
"""
from __future__ import annotations

import os
import sys
import textwrap

BANNER = "wezterm-llm :: type your prompt, blank line to send, Ctrl+D to exit"


def pick_provider() -> str | None:
    forced = os.environ.get("LLM_PROVIDER", "").strip().lower()
    if forced in {"anthropic", "openai", "google"}:
        return forced
    if os.environ.get("ANTHROPIC_API_KEY"):
        return "anthropic"
    if os.environ.get("OPENAI_API_KEY"):
        return "openai"
    if os.environ.get("GOOGLE_API_KEY"):
        return "google"
    return None


def stream_anthropic(prompt: str, history: list[dict]) -> str:
    from anthropic import Anthropic

    client = Anthropic()
    model = os.environ.get("LLM_MODEL", "claude-3-5-sonnet-latest")
    history.append({"role": "user", "content": prompt})
    full = []
    with client.messages.stream(model=model, max_tokens=2048, messages=history) as stream:
        for text in stream.text_stream:
            sys.stdout.write(text)
            sys.stdout.flush()
            full.append(text)
    sys.stdout.write("\n")
    reply = "".join(full)
    history.append({"role": "assistant", "content": reply})
    return reply


def stream_openai(prompt: str, history: list[dict]) -> str:
    from openai import OpenAI

    client = OpenAI()
    model = os.environ.get("LLM_MODEL", "gpt-4o-mini")
    history.append({"role": "user", "content": prompt})
    full = []
    stream = client.chat.completions.create(model=model, messages=history, stream=True)
    for chunk in stream:
        delta = chunk.choices[0].delta.content or ""
        if delta:
            sys.stdout.write(delta)
            sys.stdout.flush()
            full.append(delta)
    sys.stdout.write("\n")
    reply = "".join(full)
    history.append({"role": "assistant", "content": reply})
    return reply


def stream_google(prompt: str, history: list[dict]) -> str:
    import google.generativeai as genai

    genai.configure(api_key=os.environ["GOOGLE_API_KEY"])
    model_name = os.environ.get("LLM_MODEL", "gemini-1.5-flash")
    # google's history schema uses role/parts
    model = genai.GenerativeModel(model_name)
    chat = model.start_chat(history=history)
    response = chat.send_message(prompt, stream=True)
    full = []
    for chunk in response:
        if chunk.text:
            sys.stdout.write(chunk.text)
            sys.stdout.flush()
            full.append(chunk.text)
    sys.stdout.write("\n")
    # mutate history list in place
    history.clear()
    for msg in chat.history:
        history.append({"role": msg.role, "parts": [p.text for p in msg.parts]})
    return "".join(full)


def read_prompt() -> str | None:
    sys.stdout.write("\n>>> ")
    sys.stdout.flush()
    lines: list[str] = []
    try:
        for line in sys.stdin:
            if line.strip() == "" and lines:
                break
            if line.strip() == "" and not lines:
                sys.stdout.write(">>> ")
                sys.stdout.flush()
                continue
            lines.append(line)
            sys.stdout.write("... ")
            sys.stdout.flush()
    except KeyboardInterrupt:
        return None
    if not lines:
        return None
    return "".join(lines).strip()


def main() -> int:
    provider = pick_provider()
    if not provider:
        sys.stderr.write(textwrap.dedent("""
            ! No LLM API key found. Set ONE of:
                ANTHROPIC_API_KEY   (preferred)
                OPENAI_API_KEY
                GOOGLE_API_KEY
            Optional overrides: LLM_PROVIDER=anthropic|openai|google, LLM_MODEL=<name>
        """).lstrip())
        return 2

    sys.stdout.write(f"{BANNER}\nprovider: {provider}  model: {os.environ.get('LLM_MODEL', '(default)')}\n")
    sys.stdout.flush()

    history: list[dict] = []
    streamer = {"anthropic": stream_anthropic, "openai": stream_openai, "google": stream_google}[provider]

    while True:
        prompt = read_prompt()
        if prompt is None:
            sys.stdout.write("\nbye.\n")
            return 0
        try:
            streamer(prompt, history)
        except KeyboardInterrupt:
            sys.stdout.write("\n[interrupted]\n")
        except Exception as exc:  # noqa: BLE001
            sys.stderr.write(f"\n[error] {exc}\n")


if __name__ == "__main__":
    raise SystemExit(main())
