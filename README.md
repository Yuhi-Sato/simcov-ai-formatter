# simcov-ai-formatter

A CLI gem that converts SimpleCov's `coverage/.resultset.json` into a JSON format **optimized for AI / LLM consumption**.

## Why this exists

SimpleCov's `.resultset.json` records coverage as position-dependent arrays:

```json
{ "RSpec": { "coverage": { "/abs/path/foo.rb": { "lines": [null, 1, 0, 0, null, 5] } } } }
```

`lines` is a 1-indexed hit-count array (`null` = irrelevant, `0` = uncovered, `Integer >= 1` = hit count).
For an LLM to figure out "which file has which uncovered lines" from this shape, it has to scan arrays, compute summaries, and normalize paths every single time.

This gem does that preprocessing **once, deterministically, and in a token-efficient way**.

## Installation

```sh
gem install simcov-ai-formatter
```

Or in `Gemfile`:

```ruby
group :development, :test do
  gem "simcov-ai-formatter"
end
```

## Usage

### Basics

```sh
# Read coverage/.resultset.json and print AI-friendly JSON to stdout
simcov-ai-formatter

# Specify a path
simcov-ai-formatter path/to/.resultset.json

# Pretty-print for human consumption
simcov-ai-formatter --pretty | jq

# Write to a file
simcov-ai-formatter -o coverage/.resultset.ai.json
```

### Embedded source

```sh
# Embed 2 lines of context around each uncovered range so the LLM can reason about it
simcov-ai-formatter --with-source --context 2
```

### Multiple suites

For resultsets with multiple suites (e.g. RSpec + Cucumber), all suites are merged via `max(hit)` by default:

```sh
# A line covered by either RSpec or Cucumber is treated as covered
simcov-ai-formatter

# Or look at a single suite
simcov-ai-formatter --suite RSpec
```

## CLI flags

| Flag | Default | Purpose |
|---|---|---|
| `[RESULTSET_PATH]` (positional) | `coverage/.resultset.json` | Standard SimpleCov location |
| `-o`, `--output PATH` | stdout | Output destination |
| `--root PATH` | cwd | Base directory for relative paths |
| `--suite NAME` | merge all suites | Pick a single suite |
| `--with-source` | off | Embed source lines around uncovered ranges |
| `--context N` | `2` | Lines of context when `--with-source` is set |
| `--pretty` | off | Pretty-print JSON (default is minified for token efficiency) |
| `-v`, `--version` | — | Print version |
| `-h`, `--help` | — | Show help |

Exit codes: `0` success / `1` user error (missing/invalid resultset) / `2` internal error.

## Output schema

### Default

```json
{
  "schema_version": 1,
  "suite": "RSpec",
  "root": "/Users/me/proj",
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
      "uncovered_ranges": [
        { "start": 12, "end": 14 },
        { "start": 88, "end": 88 }
      ],
      "uncovered_lines": [12, 13, 14, 88]
    }
  }
}
```

When multiple suites are merged, a top-level `"suites_merged": ["RSpec", "Cucumber"]` is emitted.

### With `--with-source --context 2`

Each `uncovered_ranges` entry gains a `source` array:

```json
{
  "start": 12, "end": 14,
  "source": [
    { "line": 10, "text": "def parse(input)",        "covered": true },
    { "line": 11, "text": "  return nil if input.nil?", "covered": true },
    { "line": 12, "text": "  raise ArgumentError",     "covered": false },
    { "line": 13, "text": "  log_error(input)",        "covered": false },
    { "line": 14, "text": "  nil",                     "covered": false },
    { "line": 15, "text": "end",                       "covered": true }
  ]
}
```

If the source file is missing, the range gets `"source": null, "source_error": "missing"` and a warning summary is emitted to stderr (processing continues).

### Branch coverage

If `branches` exists in the resultset, each file gets a `branches_raw` field containing the resultset's original key shape **unchanged**.
Structured form (`{ type: "if", line: ..., then_hits: ..., else_hits: ... }`) is planned for v0.2.0.

### Schema details

- `relevant_lines` excludes `null` entries (matches SimpleCov convention).
- Files with all `null` lines (comments / blanks only) report `relevant_lines: 0, coverage_percentage: 100.0` and are excluded from the project-level denominator.
- `coverage_percentage` is rounded to 2 decimal places.
- Files outside `root` (e.g. third-party gems) are kept under keys of the form `!abs:/abs/path`.
- The output contains no timestamp — the JSON is deterministic.

## Programmatic use

The same logic is callable from Ruby:

```ruby
require "simcov_ai_formatter"

result = SimcovAiFormatter.format(
  "coverage/.resultset.json",
  root: Dir.pwd,
  with_source: true,
  context: 2
)

# result is a Hash
puts result["summary"]["coverage_percentage"]
```

## Recipes

```sh
# Files under 80% coverage
simcov-ai-formatter | jq '.files | to_entries | map(select(.value.coverage_percentage < 80)) | from_entries'

# Top 10 files by missed line count
simcov-ai-formatter | jq '.files | to_entries | sort_by(-.value.missed_lines) | .[:10] | from_entries'

# On CI failure, hand the source-annotated JSON to Claude / GPT
simcov-ai-formatter --with-source --context 3 -o /tmp/coverage.ai.json
```

## Development

```sh
bundle install
bundle exec rake test                   # run all tests
UPDATE_GOLDEN=1 bundle exec rake test   # regenerate golden files
```

## License

MIT
