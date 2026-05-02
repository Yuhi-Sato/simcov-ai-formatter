$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "minitest/autorun"
require "json"
require "fileutils"
require "tmpdir"
require "simcov_ai_formatter"

module FixtureHelpers
  FIXTURE_ROOT = File.expand_path("fixtures", __dir__)
  GOLDEN_ROOT = File.expand_path("golden", __dir__)

  def fixture_path(*parts)
    File.join(FIXTURE_ROOT, *parts)
  end

  def golden_path(name)
    File.join(GOLDEN_ROOT, name)
  end

  # Substitutes the __FIXTURE_ROOT__ placeholder with the fixture's absolute path,
  # writes the rendered resultset.json into a tempdir, and returns its path.
  def materialize_resultset(template_relpath)
    template = File.read(fixture_path(template_relpath))
    rendered = template.gsub("__FIXTURE_ROOT__", FIXTURE_ROOT)
    tmp = Dir.mktmpdir("simcov-ai-formatter-test-")
    out = File.join(tmp, ".resultset.json")
    File.write(out, rendered)
    out
  end

  def assert_golden(name, actual_json)
    path = golden_path(name)
    if ENV["UPDATE_GOLDEN"]
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, actual_json)
      puts "[golden] updated: #{path}"
      return
    end

    expected = File.read(path)
    expected_parsed = JSON.parse(expected)
    actual_parsed = JSON.parse(actual_json)
    assert_equal(expected_parsed, actual_parsed, "golden mismatch for #{name}")
  end
end

Minitest::Test.include(FixtureHelpers)
