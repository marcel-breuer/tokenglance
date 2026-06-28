# ADR 0001: SwiftPM Native macOS App

## Decision

Use Swift Package Manager with SwiftUI, AppKit where needed, Swift Charts, and Apple frameworks.

## Context

The MVP is a native menu-bar-only macOS utility for Apple Silicon and macOS 14 or newer. Docker is not technically suitable for building or validating the GUI app because the required macOS SDK and code-signing tools are host-bound.

## Consequences

Local validation uses `swift build`, `swift test`, and `scripts/package-release.sh` on macOS. The project has no third-party runtime dependencies.

