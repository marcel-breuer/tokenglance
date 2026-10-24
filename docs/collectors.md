# Collectors

| Tool | Detection | Historical import | Live updates | Token categories | Accuracy | Setup required |
| ---- | --------- | ----------------- | ------------ | ---------------- | -------- | -------------- |
| Codex CLI | `codex --version` | Local `.jsonl` token metadata under known Codex session directories | File reconciliation | input, output, cached input, reasoning, total when present | Exact for parsed token metadata | No |
| Claude Code | `claude --version` | Not enabled by default | Local OTLP/HTTP receiver + telemetry parser | input, output, cache read, cache creation | Exact for parsed `claude_code.token.usage` data points | Yes |
| Gemini CLI | `gemini --version` | Not enabled by default | Local OTLP/HTTP metrics receiver | input, output, cached input, reasoning where emitted | Exact for allowlisted token usage metrics | Yes |
| Antigravity | `agy --version` | Not yet | Not yet | Not yet verified | Unavailable until a documented local token metadata source is verified | Yes |
| Manual import | User-selected CSV/JSON metadata file | Yes | On demand | input, output, cached input, cache creation, reasoning, other, total | Exact for user-provided metadata | No |

### Claude Code setup

Claude Code has no built-in file exporter for telemetry (see
[Claude Code monitoring docs](https://code.claude.com/docs/en/monitoring-usage)). TokenGlance
runs a local, loopback-only OTLP/HTTP JSON receiver (`ClaudeTelemetryReceiver`, default port
`4319`) while the app is running, and reads what it captures from
`~/Library/Application Support/TokenGlance/claude-otel/`.

TokenGlance configures this automatically: the first time it sees Claude Code installed with no
OpenTelemetry setup at all, it adds the four required env vars to Claude Code's own
`~/.claude/settings.json` `env` block for you (`ClaudeCodeTelemetryConfigurator`). You only need
to **restart Claude Code** afterward — the collector badge shows "waiting for data" once this
happens, and switches to "detected" after your next Claude Code session sends usage.

If Claude Code already has any OpenTelemetry env var configured (even just one, e.g. from your own
setup), TokenGlance leaves it alone rather than overwriting it, and falls back to showing manual
instructions instead:

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=http/json
export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4319
```

Token usage only arrives while TokenGlance is running and the receiver is bound. The collector
badge reflects this: `setup required` (nothing configured and Claude Code has its own
conflicting OTel setup TokenGlance won't touch), `waiting for data` (receiver ready and
configured, no Claude Code session run yet), `detected` (usage flowing).

Where available, collectors also recognize project metadata from `project`,
`project_id`, `workspace`, `cwd`, `working_directory`, or `git_root` fields.
Only a salted hash is persisted for project grouping.

### Gemini CLI setup

Gemini CLI's OpenTelemetry support can include prompts and trace attributes. To
collect token counts, configure telemetry explicitly with prompt logging and
traces disabled and the local HTTP metrics endpoint below:

```json
{
  "telemetry": {
    "enabled": true,
    "target": "local",
    "useCollector": true,
    "otlpEndpoint": "http://127.0.0.1:4320",
    "otlpProtocol": "http",
    "logPrompts": false,
    "traces": false
  }
}
```

TokenGlance listens only on `127.0.0.1`. Before writing an accepted metrics
request, it retains only the token usage metric's numeric count, token type,
model, and timestamp. It drops all other metrics and attributes, including
resource labels, session IDs, prompt text, and tool data. If no supported token
metric is present, the payload is discarded. The receiver does not persist
OTLP logs or traces.

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
