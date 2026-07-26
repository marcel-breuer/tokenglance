# ADR 0002: Collector Data Sources

## Decision

Use verified local metadata only:

- Codex CLI: local session JSONL token-count metadata.
- Claude Code: documented OpenTelemetry token usage telemetry when explicitly configured by the user.
- Antigravity: executable detection through `agy`; token collection remains setup-required until a documented local metadata source is verified.

Claude Code has no built-in file exporter, so "explicitly configured by the user" is implemented
as a local, loopback-only OTLP/HTTP receiver (`ClaudeTelemetryReceiver`) that TokenGlance runs
itself and reads back from disk. This keeps the user-consent boundary intact: TokenGlance still
never writes to Claude Code's own settings or environment — the user sets the OTLP endpoint env
vars themselves, pointing at TokenGlance's receiver.

## Consequences

Collectors report setup-required or unsupported instead of fabricating usage. Antigravity is detected, but TokenGlance does not read Antigravity conversations, logs, browser-style storage, or credentials.

Claude Code token usage is only captured while TokenGlance is running and its receiver is bound;
there is no historical import for sessions that ran before telemetry was configured or before
TokenGlance was open.
