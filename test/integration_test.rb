require "test_helper"
require "open3"

class IntegrationTest < Minitest::Test
  EXE = File.expand_path("../exe/simcov-ai-formatter", __dir__)
  FIXTURE_SIMPLE_ROOT = File.expand_path("fixtures/simple", __dir__)

  def run_exe(*args)
    Open3.capture3({ "RUBYOPT" => nil }, RbConfig.ruby, EXE, *args)
  end

  def test_subprocess_default_output
    path = materialize_resultset("simple/.resultset.json.template")
    out, err, status = run_exe(path, "--root", FIXTURE_SIMPLE_ROOT)

    assert status.success?, "exit non-zero. stderr=#{err}"
    parsed = JSON.parse(out)
    assert_equal "RSpec", parsed["suite"]
    assert_includes parsed["files"].keys, "lib/foo.rb"
  end

  def test_subprocess_root_flag_changes_relative_paths
    path = materialize_resultset("simple/.resultset.json.template")

    out_with_root, _, _ = run_exe(path, "--root", FIXTURE_SIMPLE_ROOT)
    parsed_with_root = JSON.parse(out_with_root)
    assert_includes parsed_with_root["files"].keys, "lib/foo.rb"

    out_no_root, _, _ = run_exe(path, "--root", "/tmp")
    parsed_no_root = JSON.parse(out_no_root)
    assert(
      parsed_no_root["files"].keys.any? { |k| k.start_with?("!abs:") },
      "paths outside root should be marked with !abs:"
    )
  end

  def test_subprocess_with_source_emits_source_arrays
    path = materialize_resultset("simple/.resultset.json.template")
    out, _, status = run_exe(path, "--with-source", "--context", "1", "--root", FIXTURE_SIMPLE_ROOT)
    assert status.success?

    file = JSON.parse(out)["files"]["lib/foo.rb"]
    range = file["uncovered_ranges"].first
    assert_kind_of Array, range["source"]
    assert range["source"].any? { |s| s["covered"] == false }
  end

  def test_subprocess_pretty_flag_indents
    path = materialize_resultset("simple/.resultset.json.template")
    out, _, _ = run_exe(path, "--pretty", "--root", FIXTURE_SIMPLE_ROOT)
    assert_includes out, "\n  "
  end

  def test_subprocess_help_output
    out, _, status = run_exe("--help")
    assert status.success?
    assert_match(/Usage:/, out)
    assert_match(/--with-source/, out)
  end

  def test_subprocess_version
    out, _, status = run_exe("--version")
    assert status.success?
    assert_match(/\d+\.\d+\.\d+/, out)
  end

  def test_subprocess_missing_resultset_exits_1
    _, err, status = run_exe("/no/such/path/.resultset.json")
    refute status.success?
    assert_equal 1, status.exitstatus
    assert_match(/not found/, err)
  end
end
