# Data Model

`UsageEvent` is the normalized immutable event. It stores collector, tool, provider, model, UTC timestamp, token categories, hashed session/project identifiers, source kind, source fingerprint, accuracy, parser version, and import timestamp.

When a supported source provides project metadata such as a workspace, working
directory, or project identifier, TokenGlance stores only a salted hash in
`projectIdentifierHash`. Project usage views use a short prefix of that hash as
the display label; readable paths and project names are never persisted.

Anomaly detection compares each non-empty hourly or daily usage bucket with the
median of up to six preceding non-empty buckets. It reports a spike only when
usage is at least twice the baseline and at least 1,000 tokens higher. No raw
conversation content participates in the calculation.

Token fields are optional because providers expose different categories. Category totals exclude unavailable fields and never estimate tokens from text length.

Manual imports use the same `UsageEvent` shape with `collector = manual-import`
and `sourceKind = manual-import`. They are limited to metadata fields and do not
persist prompts, responses, messages, content, source code, browser records, or
provider account data.

SQLite tables:

- `usage_events`: normalized metadata with unique `id` for deduplication.
- `collection_cursors`: incremental source offsets keyed by source fingerprint.

## Schema migration and recovery

`PRAGMA user_version` tracks the local database schema. Version 1 creates both
tables and their indexes in one exclusive transaction. A failed migration rolls
back before the database is closed. Future schema changes must be added as
ordered, transactional migrations and advance `user_version` only after their
schema changes succeed.

TokenGlance rejects a database whose schema version is newer than the running
app supports. It does not downgrade, overwrite, or recreate that database.
Migration and open failures preserve the existing database files and return an
error rather than silently resetting local data. For recovery, keep the
original database and use a user-managed macOS backup; when the database
remains readable, export normalized metadata to CSV or JSON before restoring or
removing local data. Resetting data is an explicit user action.
