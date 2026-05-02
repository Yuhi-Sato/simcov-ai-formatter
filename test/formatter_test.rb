require "test_helper"

class FormatterTest < Minitest::Test
  def setup
    @root = "/proj"
  end

  def test_default_output_includes_summary_and_files
    coverage = {
      "/proj/lib/foo.rb" => { "lines" => [nil, 1, 0, 0, nil, 5] }
    }
    result = SimcovAiFormatter::Formatter.new(coverage: coverage, suite: "RSpec", root: @root).call

    assert_equal 1, result["schema_version"]
    assert_equal "RSpec", result["suite"]
    assert_equal "/proj", result["root"]
    assert_equal 1, result["summary"]["total_files"]
    assert_equal 4, result["summary"]["relevant_lines"]
    assert_equal 2, result["summary"]["covered_lines"]
    assert_equal 2, result["summary"]["missed_lines"]
    assert_equal 50.0, result["summary"]["coverage_percentage"]

    file = result["files"]["lib/foo.rb"]
    assert_equal 4, file["relevant_lines"]
    assert_equal 2, file["covered_lines"]
    assert_equal 2, file["missed_lines"]
    assert_equal 50.0, file["coverage_percentage"]
    assert_equal [3, 4], file["uncovered_lines"]
    assert_equal [{ "start" => 3, "end" => 4 }], file["uncovered_ranges"]
  end

  def test_collapses_consecutive_uncovered_lines_into_ranges
    coverage = {
      "/proj/a.rb" => { "lines" => [0, 0, 0, 1, 0, 1, 0, 0] }
    }
    file = SimcovAiFormatter::Formatter.new(coverage: coverage, suite: "s", root: @root).call["files"]["a.rb"]

    assert_equal [1, 2, 3, 5, 7, 8], file["uncovered_lines"]
    assert_equal(
      [{ "start" => 1, "end" => 3 }, { "start" => 5, "end" => 5 }, { "start" => 7, "end" => 8 }],
      file["uncovered_ranges"]
    )
  end

  def test_null_only_file_reports_100_percent_and_zero_relevant
    coverage = { "/proj/empty.rb" => { "lines" => [nil, nil, nil] } }
    result = SimcovAiFormatter::Formatter.new(coverage: coverage, suite: "s", root: @root).call

    file = result["files"]["empty.rb"]
    assert_equal 0, file["relevant_lines"]
    assert_equal 100.0, file["coverage_percentage"]
    assert_equal [], file["uncovered_ranges"]
  end

  def test_null_only_file_does_not_skew_project_percentage
    coverage = {
      "/proj/empty.rb" => { "lines" => [nil, nil] },
      "/proj/half.rb" => { "lines" => [1, 0] }
    }
    summary = SimcovAiFormatter::Formatter.new(coverage: coverage, suite: "s", root: @root).call["summary"]
    assert_equal 2, summary["total_files"]
    assert_equal 2, summary["relevant_lines"]
    assert_equal 50.0, summary["coverage_percentage"]
  end

  def test_percentage_rounded_to_two_decimals
    lines = ([1] * 1644) + ([0] * 186)
    coverage = { "/proj/big.rb" => { "lines" => lines } }
    result = SimcovAiFormatter::Formatter.new(coverage: coverage, suite: "s", root: @root).call

    assert_equal 89.84, result["summary"]["coverage_percentage"]
  end

  def test_paths_outside_root_kept_as_abs_marker
    coverage = {
      "/proj/in.rb" => { "lines" => [1] },
      "/elsewhere/out.rb" => { "lines" => [1] }
    }
    files = SimcovAiFormatter::Formatter.new(coverage: coverage, suite: "s", root: @root).call["files"]

    assert_includes files.keys, "in.rb"
    assert_includes files.keys, "!abs:/elsewhere/out.rb"
  end

  def test_branches_passed_through_as_branches_raw
    coverage = {
      "/proj/x.rb" => {
        "lines" => [1, 0],
        "branches" => { "[:if, 1, 1, 0, 2, 5]" => { "[:then, 2, ...]" => 1, "[:else, 3, ...]" => 0 } }
      }
    }
    file = SimcovAiFormatter::Formatter.new(coverage: coverage, suite: "s", root: @root).call["files"]["x.rb"]
    assert_kind_of Hash, file["branches_raw"]
    assert_includes file["branches_raw"].keys, "[:if, 1, 1, 0, 2, 5]"
  end

  def test_emits_suites_merged_when_more_than_one
    coverage = { "/proj/a.rb" => { "lines" => [1] } }
    result = SimcovAiFormatter::Formatter.new(
      coverage: coverage, suite: "merged", suites_merged: ["RSpec", "Cucumber"], root: @root
    ).call
    assert_equal ["RSpec", "Cucumber"], result["suites_merged"]
  end

  def test_does_not_emit_suites_merged_when_single_suite
    coverage = { "/proj/a.rb" => { "lines" => [1] } }
    result = SimcovAiFormatter::Formatter.new(
      coverage: coverage, suite: "RSpec", suites_merged: ["RSpec"], root: @root
    ).call
    refute_includes result.keys, "suites_merged"
  end
end
