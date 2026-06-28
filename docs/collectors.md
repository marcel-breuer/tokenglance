# Collectors

| Tool | Detection | Historical import | Live updates | Token categories | Accuracy | Setup required |
| ---- | --------- | ----------------- | ------------ | ---------------- | -------- | -------------- |
| Codex CLI | `codex --version` | Local `.jsonl` token metadata under known Codex session directories | File reconciliation | input, output, cached input, reasoning, total when present | Exact for parsed token metadata | No |
| Claude Code | `claude --version` | Not enabled by default | Documented OpenTelemetry telemetry parser | input, output, cache read, cache creation, reasoning when present | Exact for parsed telemetry | Yes |
| Antigravity | `agy --version` | Not yet | Not yet | Not yet verified | Unavailable until a documented local token metadata source is verified | Yes |

TokenGlance detects Antigravity safely but does not read Antigravity conversations, logs, browser-style storage, or credentials until a documented local token metadata source is verified.

Codex collection scans only local `.jsonl` files under:

```text
~/.codex/sessions/
~/.codex/archived_sessions/
```
