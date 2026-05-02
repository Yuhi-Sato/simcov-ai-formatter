require "test_helper"

class SuiteMergerTest < Minitest::Test
  def test_single_suite_returns_as_is
    raw = {
      "RSpec" => { "coverage" => { "/x.rb" => { "lines" => [1, 0] } } }
    }
    suite, coverage = SimcovAiFormatter::SuiteMerger.new(raw).select
    assert_equal "RSpec", suite
    assert_equal [1, 0], coverage["/x.rb"]["lines"]
  end

  def test_multiple_suites_merged_with_max_hit
    raw = {
      "RSpec" => { "coverage" => { "/x.rb" => { "lines" => [1, 0, nil, 5] } } },
      "Cucumber" => { "coverage" => { "/x.rb" => { "lines" => [0, 3, nil, 1] } } }
    }
    suite, coverage = SimcovAiFormatter::SuiteMerger.new(raw).select
    assert_equal "merged", suite
    assert_equal [1, 3, nil, 5], coverage["/x.rb"]["lines"]
  end

  def test_merge_unions_files_across_suites
    raw = {
      "RSpec" => { "coverage" => { "/a.rb" => { "lines" => [1] } } },
      "Cucumber" => { "coverage" => { "/b.rb" => { "lines" => [1] } } }
    }
    _, coverage = SimcovAiFormatter::SuiteMerger.new(raw).select
    assert_equal ["/a.rb", "/b.rb"].sort, coverage.keys.sort
  end

  def test_explicit_suite_selection
    raw = {
      "RSpec" => { "coverage" => { "/x.rb" => { "lines" => [1] } } },
      "Cucumber" => { "coverage" => { "/x.rb" => { "lines" => [0] } } }
    }
    suite, coverage = SimcovAiFormatter::SuiteMerger.new(raw, suite: "Cucumber").select
    assert_equal "Cucumber", suite
    assert_equal [0], coverage["/x.rb"]["lines"]
  end

  def test_unknown_suite_raises
    raw = { "RSpec" => { "coverage" => { "/x.rb" => { "lines" => [1] } } } }
    err = assert_raises(SimcovAiFormatter::SuiteNotFound) do
      SimcovAiFormatter::SuiteMerger.new(raw, suite: "Minitest").select
    end
    assert_match(/Minitest/, err.message)
  end

  def test_branches_summed_across_suites
    raw = {
      "RSpec" => {
        "coverage" => { "/x.rb" => { "lines" => [1], "branches" => { "k" => { "[:then]" => 2 } } } }
      },
      "Cucumber" => {
        "coverage" => { "/x.rb" => { "lines" => [1], "branches" => { "k" => { "[:then]" => 3, "[:else]" => 1 } } } }
      }
    }
    _, coverage = SimcovAiFormatter::SuiteMerger.new(raw).select
    assert_equal({ "[:then]" => 5, "[:else]" => 1 }, coverage["/x.rb"]["branches"]["k"])
  end
end
