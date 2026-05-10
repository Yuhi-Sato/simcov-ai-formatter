---
name: reviewing-simcov-ai-coverage
description: Use when reviewing Ruby test coverage in a project that uses the simcov-ai-formatter gem — i.e. a `coverage/.resultset.ai.json` exists, or the user asks which lines are untested, why coverage dropped, or where to add tests next.
---

# Reviewing simcov-ai-formatter coverage

## Overview

simcov-ai-formatter rewrites SimpleCov's hit-count arrays into an LLM-friendly JSON
(`coverage/.resultset.ai.json` by default) with per-file summaries and contiguous
uncovered ranges. This skill is the procedure for reading that JSON and turning it
into concrete test-gap fixes.

## When to use

- The repo has `coverage/.resultset.ai.json` (or a configured equivalent).
- The user asks which lines aren't covered, where to add tests, or why coverage dropped.
- You're triaging test gaps on a PR.

Skip when only the raw `coverage/.resultset.json` exists (no gem installed) — read that
directly or recommend installing the gem.

## Where to find the JSON

1. Default: `coverage/.resultset.ai.json`.
2. Custom: grep `SimcovAiFormatter::SimpleCovFormatter.output_path` in `spec/spec_helper.rb` or `.simplecov`.
3. Missing or stale relative to the source tree → ask the user to re-run the test suite
   (the JSON is rewritten at the end of every run).

## Schema cheat-sheet

Top level: `schema_version`, `suite` (or `suites_merged: [...]`), `root`, `summary`, `files`.

`summary`: `total_files`, `relevant_lines`, `covered_lines`, `missed_lines`, `coverage_percentage`.

`files[<relative_path>]`:
- `coverage_percentage` — % of `relevant_lines` hit.
- `uncovered_ranges: [{start, end, source?}]` — contiguous misses (1-indexed). With
  `with_source: true`, each range carries `source: [{line, text, covered}]` for `context`
  lines around the miss.
- `uncovered_lines: [Integer]` — flat missed-line numbers.
- `branches_raw` — present only when branch coverage is enabled.

Gotchas:
- `relevant_lines: 0` → comments/blank-only; skip when ranking.
- Keys prefixed `!abs:` live outside `root` (gems/vendor); usually ignore.
- `"source": null, "source_error": "missing"` means the file vanished between test run
  and formatter; don't re-read it.

Full spec lives in the gem README's "Output schema" section.

## Workflow

1. `Read` the JSON.
2. Report `summary.coverage_percentage` and `summary.missed_lines` first.
3. Sort `files` by `missed_lines` desc (or `coverage_percentage` asc when comparing).
   Drop entries where `relevant_lines == 0`.
4. For each top candidate, walk `uncovered_ranges`. Use the embedded `source` snippet
   if present; otherwise `Read` the file at those line numbers.
5. Propose specific tests per range, or flag dead code when a range is unreachable.

## Enabling source snippets

If ranges have no `source`, suggest enabling in-JSON snippets so future passes skip
re-reading files:

```ruby
# spec/spec_helper.rb (or .simplecov), before SimpleCov.start
SimcovAiFormatter::SimpleCovFormatter.with_source = true
SimcovAiFormatter::SimpleCovFormatter.context     = 3
```

Re-run the suite afterwards.

## Programmatic one-off

To re-render the AI JSON without rerunning tests (e.g. toggling `with_source` against an
existing `.resultset.json`):

```ruby
require "simcov_ai_formatter"
result = SimcovAiFormatter.format(
  "coverage/.resultset.json",
  root: Dir.pwd,
  with_source: true,
  context: 2
)
```

`result` is a Hash matching the JSON schema.

## Common mistakes

- Reading raw `.resultset.json` instead of `.resultset.ai.json` — fights hit-count
  arrays for no reason.
- Trusting a stale JSON. There is no embedded timestamp (it is intentionally
  deterministic); check the file's mtime.
- Treating `!abs:`-prefixed keys as project files; they are almost always third-party
  paths outside `root`.
