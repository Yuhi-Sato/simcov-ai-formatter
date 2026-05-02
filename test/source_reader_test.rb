require "test_helper"
require "stringio"

class SourceReaderTest < Minitest::Test
  def test_reads_lines_in_range
    reader = SimcovAiFormatter::SourceReader.new
    path = fixture_path("simple/lib/foo.rb")
    snippet = reader.read(path, 4, 6)

    assert_equal 3, snippet.size
    assert_equal 4, snippet[0][0]
    assert_match(/parse/, snippet[0][1])
    assert_equal 6, snippet[2][0]
  end

  def test_clamps_to_file_bounds
    reader = SimcovAiFormatter::SourceReader.new
    path = fixture_path("simple/lib/foo.rb")
    snippet = reader.read(path, -5, 10_000)

    assert_equal 1, snippet.first[0]
    refute_nil snippet.last
  end

  def test_returns_nil_for_missing_file_and_records_warning
    warnings = StringIO.new
    reader = SimcovAiFormatter::SourceReader.new(warnings: warnings)

    assert_nil reader.read("/no/such/file.rb", 1, 5)

    reader.report_missing
    assert_match %r{1 source file\(s\) not found}, warnings.string
    assert_match %r{/no/such/file\.rb}, warnings.string
  end

  def test_caches_repeated_reads
    reader = SimcovAiFormatter::SourceReader.new
    path = fixture_path("simple/lib/foo.rb")

    first = reader.read(path, 1, 5)
    second = reader.read(path, 1, 5)
    assert_equal first, second
  end

  def test_handles_non_utf8_files_without_crashing
    Dir.mktmpdir do |dir|
      path = File.join(dir, "sjis.rb")
      bytes = "# \xE6\x97".dup.force_encoding("BINARY") # incomplete UTF-8
      File.binwrite(path, bytes + "\n# ok\n")

      reader = SimcovAiFormatter::SourceReader.new
      snippet = reader.read(path, 1, 2)
      assert_equal 2, snippet.size
      assert_match(/ok/, snippet[1][1])
    end
  end
end

class FormatterWithSourceTest < Minitest::Test
  def test_with_source_attaches_source_array_to_ranges
    fixture_root = File.expand_path("fixtures", __dir__)
    abs_path = File.join(fixture_root, "simple/lib/foo.rb")
    coverage = {
      abs_path => { "lines" => [nil, nil, nil, 1, 1, 0, 0, 0, 1, 1, 1, 5, 5, 1] }
    }

    reader = SimcovAiFormatter::SourceReader.new
    result = SimcovAiFormatter::Formatter.new(
      coverage: coverage,
      suite: "RSpec",
      root: fixture_root,
      with_source: true,
      context: 1,
      source_reader: reader
    ).call

    file = result["files"]["simple/lib/foo.rb"]
    range = file["uncovered_ranges"].first
    assert_kind_of Array, range["source"]

    covered_flags = range["source"].map { |s| s["covered"] }
    assert_includes covered_flags, true
    assert_includes covered_flags, false

    line_numbers = range["source"].map { |s| s["line"] }
    assert_equal line_numbers.sort, line_numbers
  end

  def test_with_source_records_missing_when_source_file_absent
    coverage = {
      "/non/existent/file.rb" => { "lines" => [0, 0] }
    }
    warnings = StringIO.new
    reader = SimcovAiFormatter::SourceReader.new(warnings: warnings)
    result = SimcovAiFormatter::Formatter.new(
      coverage: coverage, suite: "s", root: "/non/existent",
      with_source: true, context: 1, source_reader: reader
    ).call
    reader.report_missing

    range = result["files"]["file.rb"]["uncovered_ranges"].first
    assert_nil range["source"]
    assert_equal "missing", range["source_error"]
    assert_match(/not found/, warnings.string)
  end
end
