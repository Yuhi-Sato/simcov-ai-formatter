---
name: reviewing-simcov-ai-coverage
description: Use when reading or analyzing test coverage in a Ruby project that has the simcov-ai-formatter gem installed, or whenever `coverage/.resultset.ai.json` exists.
---

# Reading simcov-ai-formatter coverage

When the user asks about test coverage in a project that uses simcov-ai-formatter, read
`coverage/.resultset.ai.json` (or the path configured via
`SimcovAiFormatter::SimpleCovFormatter.output_path`) and use its contents as the coverage
input.

That JSON is this gem's whole purpose: it is the AI-friendly form of SimpleCov's output,
with per-file `coverage_percentage`, `uncovered_ranges`, and `uncovered_lines`
precomputed. Don't read the raw `coverage/.resultset.json` — you would just be
reverse-engineering what this file already has.

If the file is missing or stale, ask the user to re-run their test suite.

## File shape

```json
{
  "schema_version": 1,
  "suite": "RSpec",
  "root": "/abs/path/to/project",
  "summary": {
    "total_files": 42,
    "relevant_lines": 1830,
    "covered_lines": 1644,
    "missed_lines": 186,
    "coverage_percentage": 89.84
  },
  "files": {
    "lib/foo.rb": {
      "relevant_lines": 50,
      "covered_lines": 45,
      "missed_lines": 5,
      "coverage_percentage": 90.0,
      "uncovered_ranges": [{ "start": 12, "end": 14 }],
      "uncovered_lines": [12, 13, 14]
    }
  }
}
```

Variations:
- With `with_source: true` set on the formatter, each `uncovered_ranges` entry also
  carries `source: [{line, text, covered}]` for `context` lines around the miss.
- When multiple suites are merged, the top level adds `"suites_merged": ["RSpec", ...]`.
- Files outside `root` (gems/vendor) are keyed `!abs:/abs/path` — usually skip them.
- Branch coverage, when enabled, lands in a per-file `branches_raw` field.
