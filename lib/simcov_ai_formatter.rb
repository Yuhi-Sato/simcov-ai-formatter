require_relative "simcov_ai_formatter/version"
require_relative "simcov_ai_formatter/errors"
require_relative "simcov_ai_formatter/resultset_loader"
require_relative "simcov_ai_formatter/suite_merger"
require_relative "simcov_ai_formatter/formatter"
require_relative "simcov_ai_formatter/source_reader"
require_relative "simcov_ai_formatter/renderer"

module SimcovAiFormatter
  DEFAULT_RESULTSET_PATH = "coverage/.resultset.json".freeze

  # Public API: convert resultset.json into an AI-friendly Hash.
  #
  # @param path [String] path to resultset.json
  # @param root [String] base directory for relative paths (default: Dir.pwd)
  # @param suite [String, nil] pick a single suite; if nil, merge all suites via max(hit)
  # @param with_source [Boolean] embed source lines around uncovered ranges
  # @param context [Integer] lines of context when with_source is true
  # @param source_warnings [IO, nil] destination for source-missing warnings
  # @return [Hash]
  def self.format(path, root: Dir.pwd, suite: nil, with_source: false, context: 2, source_warnings: nil)
    raw = ResultsetLoader.new(path).load
    selected_suite, coverage = SuiteMerger.new(raw, suite: suite).select
    source_reader = with_source ? SourceReader.new(warnings: source_warnings) : nil
    Formatter.new(
      coverage: coverage,
      suite: selected_suite,
      suites_merged: suite.nil? ? raw.keys : nil,
      root: root,
      with_source: with_source,
      context: context,
      source_reader: source_reader
    ).call
  end
end
