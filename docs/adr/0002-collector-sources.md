# ADR 0002: Collector Data Sources

## Decision

Use verified local metadata only:

- Codex CLI: local session JSONL token-count metadata.
- Claude Code: documented OpenTelemetry token usage telemetry when explicitly configured by the user.
- Antigravity: executable detection through `agy`; token collection remains setup-required until a documented local metadata source is verified.

## Consequences

Collectors report setup-required or unsupported instead of fabricating usage. Antigravity is detected, but TokenGlance does not read Antigravity conversations, logs, browser-style storage, or credentials.
