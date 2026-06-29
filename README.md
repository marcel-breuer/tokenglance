# TokenGlance

Local token usage at a glance, right in the macOS menu bar.

TokenGlance is a native, local-first macOS menu-bar app for monitoring token
usage from AI coding tools. It imports verified local token metadata, keeps the
data on your machine, and shows the current daily token count without opening a
dashboard.

![TokenGlance dashboard showing daily token totals, usage chart, and collector status](docs/assets/token-glance-dashboard.png)

## Highlights

- Menu-bar token count with live refresh.
- Dashboard for today, last 24 hours, last 7 days, and last 30 days.
- Breakdown by input, output, cache, and reasoning tokens where available.
- Collector diagnostics for supported local tools.
- CSV and JSON export of normalized usage metadata.
- Local-only storage with no account, backend, analytics, or telemetry.

## Requirements

- macOS 14 Sonoma or newer
- Apple Silicon
- Supported local tool metadata; TokenGlance never estimates from prompt text

## Installation

Install from the public Homebrew tap:

```bash
brew install --cask marcel-breuer/tap/tokenglance
```

Or tap once, then install by cask name:

```bash
brew tap marcel-breuer/tap
brew install --cask tokenglance
```

After tapping, TokenGlance is discoverable through Homebrew search:

```bash
brew search tokenglance
```

Upgrade an existing Homebrew installation:

```bash
brew update
brew upgrade --cask tokenglance
```

Some releases may be ad-hoc signed rather than Developer ID signed and notarized.
Homebrew 6 no longer accepts the old `--no-quarantine` install option. If macOS
blocks the first launch, approve TokenGlance in System Settings > Privacy &
Security or remove the quarantine attribute for this app only:

```bash
xattr -dr com.apple.quarantine /Applications/TokenGlance.app
```

Do not globally disable Gatekeeper. Verify the published SHA-256 checksum before
installing.

## Supported Tools

| Tool | Detection | Historical import | Live updates | Token categories | Accuracy | Setup required |
| ---- | --------- | ----------------- | ------------ | ---------------- | -------- | -------------- |
| Codex CLI | Yes | Yes, from verified local JSONL token metadata | Reconciliation | input, output, cached input, reasoning, total when present | Exact | No |
| Claude Code | Yes | No by default | Telemetry parser available | input, output, cache read, cache creation | Exact when telemetry is configured | Yes |
| Antigravity | Yes, via `agy --version` | Not yet | Not yet | Not yet verified | Unavailable until a documented local token metadata source is verified | Yes |

Codex usage is imported from local token-count metadata in:

```text
~/.codex/sessions/
~/.codex/archived_sessions/
```

Antigravity is detected safely, but TokenGlance does not read Antigravity
conversations, logs, browser-style storage, or credentials until a documented
local token metadata source is verified.

## Privacy

All processing is local. TokenGlance does not upload usage data and does not read
credentials, browser data, shell history, clipboard contents, prompts, responses,
source code, or private provider APIs. Raw content encountered near metadata is
discarded and never persisted.

Data is stored under:

```text
~/Library/Application Support/TokenGlance/
```

Deleting local usage data removes TokenGlance's database records and collector
cursors; it never modifies source files belonging to external tools.

## Manual Installation

1. Download `TokenGlance-<version>-arm64.zip` from the official GitHub release.
2. Verify the published SHA-256 checksum.
3. Extract `TokenGlance.app`.
4. Move it to `/Applications`.
5. Open it and approve the launch in macOS Privacy & Security if Gatekeeper
   blocks the first launch.

## Development

```bash
swift build
swift test
./scripts/package-release.sh 0.1.1
```

Docker is preferred when available, but this repository is a native macOS app and
requires the local macOS SDK/Xcode toolchain for build, test, and packaging.

## Release

The release script builds an optimized ARM64 app, signs it, verifies the app
bundle, creates a ZIP, and writes a SHA-256 checksum:

```bash
./scripts/package-release.sh 0.1.1
```

Artifacts:

- `dist/TokenGlance.app`
- `dist/TokenGlance-0.1.1-arm64.zip`
- `dist/TokenGlance-0.1.1-arm64.zip.sha256`

The GitHub release workflow updates the Homebrew cask after creating the release.
Configure `HOMEBREW_TAP_TOKEN` as a repository secret with write access to the tap
repository. The workflow defaults to `marcel-breuer/homebrew-tap`; set the
repository variable `HOMEBREW_TAP_REPOSITORY` to override it.

Developer ID signing and notarization are optional for local development but
required before submitting TokenGlance to the official Homebrew Cask tap. To
produce a Gatekeeper-accepted release in CI, configure these repository secrets:

- `DEVELOPER_ID_CERTIFICATE_BASE64`: base64-encoded `.p12` Developer ID
  Application certificate.
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`: password for the `.p12` certificate.
- `DEVELOPER_ID_APPLICATION`: exact codesign identity, for example
  `Developer ID Application: Example Name (TEAMID)`.
- `KEYCHAIN_PASSWORD`: temporary CI keychain password.
- `APPLE_ID`: Apple ID used for notarization.
- `APPLE_TEAM_ID`: Apple Developer Team ID.
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization.

With those secrets present, `./scripts/package-release.sh` signs with the
Developer ID identity, submits the ZIP to Apple notarization, staples the app,
verifies it with Gatekeeper, and regenerates the final ZIP/checksum.

## Official Homebrew Listing

TokenGlance is not listed on brew.sh/formulae.brew.sh yet because those pages
index the official Homebrew taps. To appear there, TokenGlance must be accepted
into `Homebrew/homebrew-cask`.

Before submitting, the app should launch with Gatekeeper enabled on supported
macOS versions, meet Homebrew's notability expectations for new, self-submitted
casks, and pass Homebrew Cask audit. Until then, the public tap remains the
supported distribution channel for external users.

## Roadmap

- User-approved Claude Code telemetry setup helper.
- User-approved Antigravity token metadata setup when a documented local source
  is verified.
- Additional collectors only after documented local metadata sources are
  verified.

## License

MIT
