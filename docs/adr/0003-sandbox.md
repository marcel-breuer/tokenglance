# ADR 0003: App Sandbox

## Decision

Do not enable App Sandbox for the initial unsigned Homebrew-distributed MVP.

## Context

The app needs read-only access to user-authorized local telemetry/session files outside its container. Sandboxing would require additional user-selected bookmarks and would make initial collector validation harder for a menu-bar utility distributed outside the Mac App Store.

## Consequences

The app still avoids Full Disk Access, private APIs, credentials, browser data, and broad home-directory scans. Future releases can revisit sandboxing with explicit security-scoped bookmarks.

