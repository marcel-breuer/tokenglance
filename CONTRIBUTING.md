# Contributing

Use Swift, SwiftUI, Swift concurrency, and Apple frameworks by default. Keep collectors isolated behind `UsageCollector` and never add support claims without a verified data source, synthetic fixtures, and automated tests.

Run before opening a pull request:

```bash
swift build
swift test
./scripts/package-release.sh 0.1.0
```

Use Conventional Commits. Do not commit secrets, real user logs, prompts, responses, source code, credentials, or AI attribution.

