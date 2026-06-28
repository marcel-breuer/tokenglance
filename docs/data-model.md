# Data Model

`UsageEvent` is the normalized immutable event. It stores collector, tool, provider, model, UTC timestamp, token categories, hashed session/project identifiers, source kind, source fingerprint, accuracy, parser version, and import timestamp.

Token fields are optional because providers expose different categories. Category totals exclude unavailable fields and never estimate tokens from text length.

SQLite tables:

- `usage_events`: normalized metadata with unique `id` for deduplication.
- `collection_cursors`: incremental source offsets keyed by source fingerprint.

