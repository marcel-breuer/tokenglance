# Features

TokenGlance is a local-first macOS menu-bar monitor for structured AI usage
metadata. The dashboard combines collection, aggregation, diagnostics, and
export without sending usage data to a backend.

## Dashboard

- **Usage overview** shows today, the last 24 hours, the last 7 days, or the
  last 30 days.
- **Token mix** separates input, output, cached input, reasoning, cache
  creation, other, and total tokens when a source provides those categories.
- **Usage chart** shows normalized activity over time without estimating usage
  from prompt or response text.
- **Burn Rate** reports recent token velocity, while **Token Weather** labels
  current activity as calm, active, or stormy and projects today's usage.
- **Model Efficiency** compares models by event count, average event size,
  cache share, reasoning share, and optional local cost estimates.

All dashboard sections follow the selected period, tool, and model filters.

## Project Usage

Project Usage groups events by project metadata when a collector or import file
provides one of these fields:

`project`, `project_id`, `workspace`, `cwd`, `working_directory`, or `git_root`.

The view shows a stable privacy-safe label, event count, latest activity, token
total, token mix, and optional local cost estimate. The source value is never
persisted. Instead, TokenGlance hashes it locally with a per-installation salt
and displays only a short prefix of that hash. This keeps project comparisons
useful without exposing readable paths, repository names, or workspace names.

Events without project metadata remain available in the overall dashboard but
are not assigned to a project group.

## Menu-bar monitoring

The menu-bar item can show:

- an always-on Usage Strip with a compact colored sparkline and today's total;
- today's sparkline only;
- today's total, last-hour tokens, input tokens, or output tokens; or
- an icon-only mode.

The tooltip includes non-sensitive local analytics such as today's total, peak
hour, top model, cache share, burn rate, and projected usage. Live refresh runs
at a configurable interval and imports only incremental metadata changes.

## Collectors and imports

Built-in collectors support verified local metadata from Codex CLI, a documented
Claude Code telemetry format, and safe Antigravity CLI detection. Manual CSV or
JSON import supports metadata exports from ChatGPT, Claude, Gemini, OpenAI API,
Anthropic API, and Google AI API.

Imports normalize metadata fields into the same `UsageEvent` model. Prompt text,
responses, messages, source code, credentials, browser data, cookies, private
provider APIs, and raw content fields are ignored and never written to the
local database.

## Reports and diagnostics

- Weekly Markdown reports can be copied and archived locally.
- Schema Drift Radar identifies metadata records that exist but no longer match
  a supported parser shape.
- Collector diagnostics report setup status, parser health, and redacted errors.
- CSV and JSON exports contain normalized metadata only.

## Data boundaries

TokenGlance stores normalized events and settings under:

```text
~/Library/Application Support/TokenGlance/
```

The application has no account, backend, analytics, or telemetry service. Local
data deletion removes TokenGlance's database records and cursors but does not
modify files owned by external AI tools.
