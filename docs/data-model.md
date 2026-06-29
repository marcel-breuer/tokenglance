# Data Model

`UsageEvent` is the normalized immutable event. It stores collector, tool, provider, model, UTC timestamp, token categories, hashed session/project identifiers, source kind, source fingerprint, accuracy, parser version, and import timestamp.

Token fields are optional because providers expose different categories. Category totals exclude unavailable fields and never estimate tokens from text length.

Manual imports use the same `UsageEvent` shape with `collector = manual-import`
and `sourceKind = manual-import`. They are limited to metadata fields and do not
persist prompts, responses, messages, content, source code, browser records, or
provider account data.

SQLite tables:

- `usage_events`: normalized metadata with unique `id` for deduplication.
- `collection_cursors`: incremental source offsets keyed by source fingerprint.
