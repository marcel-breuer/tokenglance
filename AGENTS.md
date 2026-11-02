# AGENTS.md

Build and validate inside Docker when technically possible. This project is a native macOS SwiftUI application, so Swift builds, tests, packaging, signing checks, and Homebrew validation require the local macOS/Xcode toolchain unless a macOS container or project-specific replacement exists.

Architecture:

- Keep app lifecycle, UI, collection, parsing, persistence, aggregation, settings, diagnostics, privacy, export, and release code separated.
- Use `TokenGlanceCore` for business logic and keep SwiftUI views thin.
- Add collectors behind `UsageCollector`; do not let one collector failure break others.

Swift conventions:

- Prefer immutable value types, explicit dependency injection, actors for mutable shared state, and structured concurrency.
- Do not block the main actor with file or database work.
- Do not suppress compiler warnings globally.

Privacy and security:

- Never persist prompts, responses, source code, credentials, raw paths, session identifiers, browser data, shell history, clipboard contents, or network captures.
- Do not read private provider APIs, cookies, keychains, OAuth tokens, API keys, or authentication databases.
- Use synthetic fixtures only. Never commit real user logs, prompts, responses, source code, session files, or credentials.
- Redact diagnostics and report unsupported schemas honestly.

Testing:

- Add parser fixtures and automated tests for every supported collector.
- Run `swift build` and `swift test` before reporting success.
- Run `./scripts/package-release.sh 0.1.0` for release artifact validation.

Dependencies:

- Prefer Apple frameworks.
- Add third-party dependencies only after documenting maintenance, license, security, size, transitive dependencies, macOS support, and Swift concurrency compatibility.

Git and PRs:

- Use Conventional Commits.
- Do not mention AI assistant, automation tool, or code generation tool attribution in commits, pull requests, docs, comments, or release notes.
- Branch names must describe the work directly and must not use tool branding.

Output:

- Keep progress reports concise and token-efficient.
- Report failures and remaining blockers exactly; do not fabricate support claims.

## User interface work

- For new SwiftUI views, UI redesigns, and focused UI reviews, use the project skill in `.agents/skills/unslop/SKILL.md` (`$unslop`). Read its audit before editing and keep existing product behavior, branding, design tokens, and reusable components.
- Audit the current UI first. If it is already well designed, make only evidence-based fixes; do not redesign it without a concrete issue.
- The upstream skill's snapshot and story scripts target browser pages. For SwiftUI, inspect the native view and use an available macOS/Xcode screenshot workflow; do not treat browser-only steps as applicable.
- Preserve the skill's attribution and version record when updating it.
