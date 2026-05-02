# Changelog

## [0.1.0] - 2026-05-03

### Added
- Initial release.
- CLI `simcov-ai-formatter` converts SimpleCov's `.resultset.json` into AI-friendly JSON.
- Per-file and project-wide summaries (line counts, coverage percentage).
- `uncovered_ranges` (consecutive uncovered lines collapsed into ranges) and flat `uncovered_lines`.
- `--with-source --context N` embeds source lines around uncovered ranges.
- Multiple suites are merged via `max(hit)`, or a single suite can be selected with `--suite NAME`.
- Output destinations: stdout (default) or `--output PATH`.
- Public Ruby API: `SimcovAiFormatter.format(path, **opts)` returns a Hash.
