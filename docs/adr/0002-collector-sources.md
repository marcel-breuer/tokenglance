# ADR 0002: Collector Data Sources

## Decision

Use verified local metadata only:

- Codex CLI: local session JSONL token-count metadata.
- Claude Code: documented OpenTelemetry token usage telemetry when explicitly configured by the user.
- Antigravity: executable detection through `agy`; token collection remains setup-required until a documented local metadata source is verified.

Claude Code has no built-in file exporter, so "explicitly configured by the user" is implemented
as a local, loopback-only OTLP/HTTP receiver (`ClaudeTelemetryReceiver`) that TokenGlance runs
itself and reads back from disk.

Superseding the original version of this ADR: TokenGlance now writes the four required OTLP env
vars into Claude Code's own `~/.claude/settings.json` `env` block automatically
(`ClaudeCodeTelemetryConfigurator`), so an end user doesn't have to run `export` commands
themselves. This does touch Claude Code's own config, unlike the original "never writes to Claude
Code's own settings" stance — the tradeoff was made deliberately to remove the last manual step.
The consent boundary is preserved a different way: TokenGlance only fills in those four keys when
none of them are present at all. If Claude Code (or the user) already has any one of them
configured — even pointing somewhere else — TokenGlance leaves the whole block untouched and
falls back to showing the manual `export` instructions instead of overwriting an existing setup.

## Consequences

Collectors report setup-required or unsupported instead of fabricating usage. Antigravity is detected, but TokenGlance does not read Antigravity conversations, logs, browser-style storage, or credentials.

Claude Code token usage is only captured while TokenGlance is running and its receiver is bound;
there is no historical import for sessions that ran before telemetry was configured or before
TokenGlance was open. After TokenGlance writes the env block, Claude Code still needs to be
restarted before it picks up the new environment — TokenGlance cannot do that part.
