require "test_helper"
require "stringio"

class CLITest < Minitest::Test
  def run_cli(args, stdout: StringIO.new, stderr: StringIO.new)
    code = SimcovAiFormatter::CLI.new(args, stdout: stdout, stderr: stderr).run
    [code, stdout.string, stderr.string]
  end

  def test_default_outputs_minified_json_to_stdout
    path = materialize_resultset("simple/.resultset.json.template")

    code, out, err = run_cli([path, "--root", File.expand_path("fixtures/simple", __dir__)])
    assert_equal SimcovAiFormatter::CLI::EXIT_OK, code
    assert_empty err

    refute_includes out, "\n  ", "minified output should not contain pretty indentation"

    parsed = JSON.parse(out)
    assert_equal 1, parsed["schema_version"]
    assert_equal "RSpec", parsed["suite"]
    assert_includes parsed["files"].keys, "lib/foo.rb"
  end

  def test_pretty_flag_produces_indented_json
    path = materialize_resultset("simple/.resultset.json.template")

    _, out, _ = run_cli([path, "--pretty", "--root", File.expand_path("fixtures/simple", __dir__)])
    assert_includes out, "\n  ", "pretty output should contain indentation"
  end

  def test_missing_resultset_returns_exit_1
    code, _, err = run_cli(["/nonexistent/.resultset.json"])
    assert_equal SimcovAiFormatter::CLI::EXIT_USER_ERROR, code
    assert_match(/not found/, err)
  end

  def test_invalid_resultset_returns_exit_1
    Dir.mktmpdir do |dir|
      path = File.join(dir, "broken.json")
      File.write(path, "{ broken")
      code, _, err = run_cli([path])
      assert_equal SimcovAiFormatter::CLI::EXIT_USER_ERROR, code
      assert_match(/invalid JSON/, err)
    end
  end

  def test_output_flag_writes_to_file
    path = materialize_resultset("simple/.resultset.json.template")

    Dir.mktmpdir do |dir|
      out_path = File.join(dir, "out.json")
      code, _, _ = run_cli([
        path,
        "--output", out_path,
        "--root", File.expand_path("fixtures/simple", __dir__)
      ])
      assert_equal SimcovAiFormatter::CLI::EXIT_OK, code
      assert File.exist?(out_path)
      parsed = JSON.parse(File.read(out_path))
      assert_includes parsed["files"].keys, "lib/foo.rb"
    end
  end
end
