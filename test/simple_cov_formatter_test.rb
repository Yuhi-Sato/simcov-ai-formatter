require "test_helper"
require "simcov_ai_formatter/simple_cov_formatter"

class SimpleCovFormatterTest < Minitest::Test
  ResultStub = Struct.new(:to_hash)

  def setup
    @formatter_class = SimcovAiFormatter::SimpleCovFormatter
    @prev_with_source = @formatter_class.with_source
    @prev_context = @formatter_class.context
    @prev_pretty = @formatter_class.pretty
    @prev_output = @formatter_class.output_path
  end

  def teardown
    @formatter_class.with_source = @prev_with_source
    @formatter_class.context = @prev_context
    @formatter_class.pretty = @prev_pretty
    @formatter_class.output_path = @prev_output
  end

  def make_result(coverage_hash)
    ResultStub.new({
      "RSpec" => {
        "coverage" => coverage_hash,
        "timestamp" => 1700000000
      }
    })
  end

  def with_captured_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def test_writes_ai_json_to_configured_output_path
    Dir.mktmpdir do |dir|
      out = File.join(dir, "ai.json")
      @formatter_class.output_path = out

      result = make_result({
        "/proj/lib/foo.rb" => { "lines" => [nil, 1, 0, 0, 1] }
      })
      with_captured_stdout { @formatter_class.new.format(result) }

      assert File.exist?(out)
      parsed = JSON.parse(File.read(out))
      assert_equal "RSpec", parsed["suite"]
      assert_equal 1, parsed["schema_version"]
    end
  end

  def test_default_output_path_falls_back_to_coverage_dir
    Dir.mktmpdir do |dir|
      coverage_dir = File.join(dir, "coverage")
      FileUtils.mkdir_p(coverage_dir)

      stub_constant_value(:SimpleCov) do
        Module.new.tap do |m|
          m.define_singleton_method(:coverage_path) { coverage_dir }
          m.define_singleton_method(:root) { dir }
        end
      end

      result = make_result({ "/proj/a.rb" => { "lines" => [1] } })
      with_captured_stdout { @formatter_class.new.format(result) }

      target = File.join(coverage_dir, ".resultset.ai.json")
      assert File.exist?(target), "expected #{target} to exist"
    ensure
      Object.send(:remove_const, :SimpleCov) if Object.const_defined?(:SimpleCov)
    end
  end

  def test_respects_class_level_with_source_and_context
    Dir.mktmpdir do |dir|
      out = File.join(dir, "ai.json")
      @formatter_class.output_path = out
      @formatter_class.with_source = true
      @formatter_class.context = 1

      fixture_root = File.expand_path("fixtures", __dir__)
      foo = File.join(fixture_root, "simple/lib/foo.rb")

      result = make_result({
        foo => { "lines" => [nil, nil, nil, 1, 1, 0, 0, 0, 1, 1, 1, 5, 5, 1] }
      })
      stub_simplecov_root(fixture_root) do
        with_captured_stdout { @formatter_class.new.format(result) }
      end

      parsed = JSON.parse(File.read(out))
      ranges = parsed["files"]["simple/lib/foo.rb"]["uncovered_ranges"]
      assert ranges.first["source"].any? { |s| s["covered"] == false }
    end
  end

  def test_pretty_flag_indents_output
    Dir.mktmpdir do |dir|
      out = File.join(dir, "ai.json")
      @formatter_class.output_path = out
      @formatter_class.pretty = true

      result = make_result({ "/proj/a.rb" => { "lines" => [1, 0] } })
      with_captured_stdout { @formatter_class.new.format(result) }

      assert_includes File.read(out), "\n  ", "pretty output should be indented"
    end
  end

  private

  def stub_simplecov_root(root)
    Object.const_set(:SimpleCov, Module.new) unless Object.const_defined?(:SimpleCov)
    sc = Object.const_get(:SimpleCov)
    sc.define_singleton_method(:root) { root }
    sc.define_singleton_method(:coverage_path) { File.join(root, "coverage") }
    yield
  ensure
    Object.send(:remove_const, :SimpleCov) if Object.const_defined?(:SimpleCov)
  end

  def stub_constant_value(name)
    Object.send(:remove_const, name) if Object.const_defined?(name)
    Object.const_set(name, yield)
  end
end
