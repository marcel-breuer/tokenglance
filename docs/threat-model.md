# Threat Model

TokenGlance defends against accidental prompt, response, source-code, credential, browser-session, and diagnostic exposure by parsing only structured metadata and redacting diagnostics.

Controls:

- Read-only source access.
- Known collector directories only.
- No credential extraction.
- No browser database access.
- No private provider endpoints.
- No traffic interception.
- No prompt or response persistence.
- Input and file-size limits in collectors.
- Symlink validation before reading source files.
- SQLite local storage only.
- Deterministic release checksum generation.

The app is unsigned or ad-hoc signed only. Users must understand Gatekeeper prompts and verify release checksums.

