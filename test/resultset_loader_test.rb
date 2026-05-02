require "test_helper"

class ResultsetLoaderTest < Minitest::Test
  def test_loads_valid_resultset
    path = materialize_resultset("simple/.resultset.json.template")
    raw = SimcovAiFormatter::ResultsetLoader.new(path).load

    assert_kind_of Hash, raw
    assert_includes raw.keys, "RSpec"
    assert raw["RSpec"]["coverage"].any?
  end

  def test_raises_when_file_missing
    err = assert_raises(SimcovAiFormatter::ResultsetNotFound) do
      SimcovAiFormatter::ResultsetLoader.new("/nonexistent/path.json").load
    end
    assert_match(/not found/, err.message)
  end

  def test_raises_on_invalid_json
    Dir.mktmpdir do |dir|
      path = File.join(dir, "broken.json")
      File.write(path, "{ this is not json")
      err = assert_raises(SimcovAiFormatter::InvalidResultset) do
        SimcovAiFormatter::ResultsetLoader.new(path).load
      end
      assert_match(/invalid JSON/, err.message)
    end
  end

  def test_raises_on_empty_top_level
    Dir.mktmpdir do |dir|
      path = File.join(dir, "empty.json")
      File.write(path, "{}")
      assert_raises(SimcovAiFormatter::InvalidResultset) do
        SimcovAiFormatter::ResultsetLoader.new(path).load
      end
    end
  end

  def test_raises_when_coverage_missing
    Dir.mktmpdir do |dir|
      path = File.join(dir, "noc.json")
      File.write(path, JSON.generate("RSpec" => { "timestamp" => 1 }))
      assert_raises(SimcovAiFormatter::InvalidResultset) do
        SimcovAiFormatter::ResultsetLoader.new(path).load
      end
    end
  end

  def test_raises_when_lines_missing
    Dir.mktmpdir do |dir|
      path = File.join(dir, "nol.json")
      File.write(path, JSON.generate("RSpec" => { "coverage" => { "/x.rb" => {} } }))
      assert_raises(SimcovAiFormatter::InvalidResultset) do
        SimcovAiFormatter::ResultsetLoader.new(path).load
      end
    end
  end
end
