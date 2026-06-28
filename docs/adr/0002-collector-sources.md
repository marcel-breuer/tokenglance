# ADR 0002: Collector Data Sources

## Decision

Use verified local metadata only:

- Codex CLI: local session JSONL token-count metadata.
- Claude Code: documented OpenTelemetry token usage telemetry when explicitly configured by the user.
- Gemini CLI: documented telemetry output when explicitly configured with prompt logging disabled.

## Consequences

Collectors report setup-required or unsupported instead of fabricating usage. Antigravity is excluded from the MVP until a documented local token metadata source is verified.

