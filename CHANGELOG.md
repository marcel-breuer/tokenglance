# Changelog

## 0.1.0

### Added

- Native SwiftUI menu-bar app shell for Apple Silicon Macs on macOS 14 or newer.
- Local SQLite persistence for normalized token usage metadata.
- Codex CLI local JSONL token metadata parser with cumulative-counter delta handling.
- Claude Code and Gemini CLI local telemetry parsers with synthetic fixtures.
- Dashboard totals, hourly/daily chart, tool filter, model filter, collector status, settings, diagnostics, CSV export support, JSON export support, retention deletion primitives, and local data deletion.
- Release packaging script for an ad-hoc signed `TokenGlance.app`, ZIP archive, and SHA-256 checksum.
- Homebrew Cask template for the personal tap distribution path.

### Known Limitations

- Claude Code live collection requires explicit local OpenTelemetry configuration and is reported as setup-required by default.
- Gemini CLI live collection requires the `gemini` executable and explicit local telemetry configuration with prompt logging disabled.
- Antigravity is detected only as a non-MVP future candidate and is not imported.

