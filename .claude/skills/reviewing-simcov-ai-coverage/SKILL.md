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
