# Collectors

| Tool | Detection | Historical import | Live updates | Token categories | Accuracy | Setup required |
| ---- | --------- | ----------------- | ------------ | ---------------- | -------- | -------------- |
| Codex CLI | `codex --version` | Local `.jsonl` token metadata under known Codex session directories | File reconciliation | input, output, cached input, reasoning, total when present | Exact for parsed token metadata | No |
| Claude Code | `claude --version` | Not enabled by default | Documented OpenTelemetry telemetry parser | input, output, cache read, cache creation, reasoning when present | Exact for parsed telemetry | Yes |
| Gemini CLI | `gemini --version` | Not enabled by default | Documented telemetry parser | input, output, cached content, thoughts/reasoning, tool, total when present | Exact for parsed telemetry | Yes |

Antigravity is not part of the MVP collector set. It may be evaluated later only if a documented local metadata source exists.

