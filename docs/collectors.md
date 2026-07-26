# Collectors

| Tool | Detection | Historical import | Live updates | Token categories | Accuracy | Setup required |
| ---- | --------- | ----------------- | ------------ | ---------------- | -------- | -------------- |
| Codex CLI | `codex --version` | Local `.jsonl` token metadata under known Codex session directories | File reconciliation | input, output, cached input, reasoning, total when present | Exact for parsed token metadata | No |
| Claude Code | `claude --version` | Not enabled by default | Local OTLP/HTTP receiver + telemetry parser | input, output, cache read, cache creation | Exact for parsed `claude_code.token.usage` data points | Yes |
| Antigravity | `agy --version` | Not yet | Not yet | Not yet verified | Unavailable until a documented local token metadata source is verified | Yes |
| Manual import | User-selected CSV/JSON metadata file | Yes | On demand | input, output, cached input, cache creation, reasoning, other, total | Exact for user-provided metadata | No |

### Claude Code setup

Claude Code has no built-in file exporter for telemetry (see
[Claude Code monitoring docs](https://code.claude.com/docs/en/monitoring-usage)). TokenGlance
runs a local, loopback-only OTLP/HTTP JSON receiver (`ClaudeTelemetryReceiver`, default port
`4319`) while the app is running, and reads what it captures from
`~/Library/Application Support/TokenGlance/claude-otel/`. TokenGlance never edits Claude Code's
own configuration — set these yourself (e.g. in your shell profile or `.claude/settings.json`)
and restart Claude Code:

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=http/json
export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4319
```

Token usage only arrives while TokenGlance is running and the receiver is bound. The collector
badge reflects this: `setup required` (no telemetry ever received), `waiting for data` (receiver
ready, no Claude Code session run yet), `detected` (usage flowing).

Where available, collectors also recognize project metadata from `project`,
`project_id`, `workspace`, `cwd`, `working_directory`, or `git_root` fields.
Only a salted hash is persisted for project grouping.

TokenGlance detects Antigravity safely but does not read Antigravity conversations, logs, browser-style storage, or credentials until a documented local token metadata source is verified.

Codex collection scans only local `.jsonl` files under:

```text
~/.codex/sessions/
~/.codex/archived_sessions/
```

Manual import supports ChatGPT, Claude, Gemini, OpenAI API, Anthropic API, and
Google AI API usage metadata without reading private app stores, browser data,
provider accounts, cookies, or private APIs. The accepted CSV/JSON fields are
timestamp, tool, provider, model, input tokens, output tokens, cached input
tokens, cache creation tokens, reasoning tokens, other tokens, and total tokens.
Conversation text fields are ignored.
