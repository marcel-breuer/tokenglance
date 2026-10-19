# Architecture and Performance Baseline

## Data flow

Collectors implement `UsageCollector` and own source discovery, cursor handling,
and collection status. Provider-specific parsers turn source records into
`CollectionBatch` values containing normalized `UsageEvent` records. Source
paths, prompts, responses, and source code do not cross into the persistence
model; session and project identifiers are salted hashes.

The app coordinates collectors and the `UsageDatabase` actor. SQLite stores
only normalized metadata and collection cursors. Aggregation, anomaly analysis,
and Markdown/CSV/JSON reporting operate on `UsageEvent`, independently of
provider file formats. New providers should add a collector and parser without
adding source-format logic to persistence or reporting.

See [Data Model](data-model.md) for schema migration and recovery behavior.

## Reproducible workload

`OptimizationBaselineTests` generates a deterministic, synthetic JSONL history
with 10,000 Codex-style token records (1,980,000 input bytes). Each record has
100 input tokens, 50 output tokens, and the same timestamp. It records parsing,
three SQLite batch imports, a full-range database fetch, aggregation, weekly
report generation, and the closed database size after 1,000, 5,000, and 10,000
records.

Run it with:

```sh
swift test --filter OptimizationBaselineTests
```

The test has no timing thresholds. Compare runs on the same machine and build
configuration; elapsed times are reference measurements, not CI performance
gates.

The measured hot paths now reuse one insert statement per SQLite batch, parse
common ISO 8601 timestamps without constructing a formatter per record, and
build daily report totals in one pass. Other timestamp formats retain a
Foundation parser fallback.

## Reference measurement

Measured 2026-10-19 on macOS 27.0.1, Apple M1, Swift 6.4, using a non-optimized
Core build. Times are one local run and are reported in milliseconds.

| Stage | Time |
| --- | ---: |
| Parse 10,000 records | 1,568 ms |
| Import 10,000 records | 66 ms |
| Fetch 10,000 records | 19 ms |
| Aggregate 10,000 records | 75 ms |
| Generate weekly Markdown report | 41 ms |

| Stored records | SQLite database size |
| ---: | ---: |
| 1,000 | 565,248 bytes |
| 5,000 | 2,650,112 bytes |
| 10,000 | 5,238,784 bytes |

The 10,000-record database uses about 524 bytes per event, including table and
index overhead. The first page and schema account for a larger share of the
1,000-record size. This baseline excludes WAL files after the database is
closed and does not model long-running growth, retention, or different event
metadata distributions.
