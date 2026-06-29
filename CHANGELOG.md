# Changelog

## Unreleased

### Changed

- Added automatic live refresh so exact local token metadata is imported without pressing refresh manually.
- Replaced Gemini CLI detection with Antigravity CLI detection through `agy`.
- Added a generated macOS app icon.
- Fixed Codex imports for current `event_msg.payload.info` token-count metadata and archived session files.
- Started background collection when the menu-bar item appears instead of waiting for the popover to open.
- Added automatic release creation after pushes to `main`.
- Preserved Codex model metadata from session records for token-count events.
- Formatted chart axis labels without scientific notation.
- Added a selectable tiny menu-bar sparkline for today's token usage.
- Added a local weekly Markdown report with trends, peak usage, top models, and cache share.
- Added Burn Rate and Token Weather indicators for current local usage intensity.
- Added automatic relaunch when the installed app bundle changes while TokenGlance is running.
- Added model efficiency analytics, local cost profiles, report archiving, schema drift diagnostics, and refreshed README screenshots.

## 0.1.1

### Changed

- Updated Homebrew and Gatekeeper documentation for Homebrew 6, which no longer accepts `--no-quarantine`.
- Improved GUI-launched collector detection by checking standard Homebrew paths even when the app receives a sparse macOS environment.
- Reworked the menu-bar popover into a compact monitor-style interface with internal overview, settings, and diagnostics modes.
- Added workflow-dispatch release automation that creates the tag and GitHub Release from a supplied semantic version.

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
