require_relative "../simcov_ai_formatter"

module SimcovAiFormatter
  # SimpleCov plugin formatter — emits the AI-friendly JSON during a SimpleCov
  # run, without requiring a separate `simcov-ai-formatter` invocation.
  #
  # Usage:
  #   require "simcov_ai_formatter/simple_cov_formatter"
  #
  #   SimpleCov.formatter = SimcovAiFormatter::SimpleCovFormatter
  #
  #   # or alongside other formatters:
  #   SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.create([
  #     SimpleCov::Formatter::HTMLFormatter,
  #     SimcovAiFormatter::SimpleCovFormatter
  #   ])
  #
  # Configure (before SimpleCov.start):
  #   SimcovAiFormatter::SimpleCovFormatter.with_source = true
  #   SimcovAiFormatter::SimpleCovFormatter.context     = 3
  #   SimcovAiFormatter::SimpleCovFormatter.pretty      = true
  #   SimcovAiFormatter::SimpleCovFormatter.output_path = "tmp/coverage.ai.json"
  class SimpleCovFormatter
    DEFAULT_OUTPUT_FILENAME = ".resultset.ai.json".freeze

    class << self
      attr_accessor :with_source, :context, :pretty, :output_path
    end
    self.with_source = false
    self.context = 2
    self.pretty = false
    self.output_path = nil

    # SimpleCov calls this with a SimpleCov::Result instance.
    def format(result)
      with_source = self.class.with_source
      context = self.class.context
      pretty = self.class.pretty

      raw = result.to_hash
      selected_suite, coverage = SuiteMerger.new(raw).select

      source_reader = with_source ? SourceReader.new(warnings: $stderr) : nil
      formatted = Formatter.new(
        coverage: coverage,
        suite: selected_suite,
        suites_merged: nil,
        root: simplecov_root,
        with_source: with_source,
        context: context,
        source_reader: source_reader
      ).call

      json = Renderer.new(pretty: pretty).render(formatted)
      target = resolve_output_path
      File.write(target, json + "\n")
      source_reader&.report_missing

      puts "Coverage AI report generated to #{target}"
      target
    end

    private

    def resolve_output_path
      self.class.output_path || File.join(simplecov_coverage_path, DEFAULT_OUTPUT_FILENAME)
    end

    def simplecov_coverage_path
      defined?(::SimpleCov) ? ::SimpleCov.coverage_path : "coverage"
    end

    def simplecov_root
      defined?(::SimpleCov) ? ::SimpleCov.root : Dir.pwd
    end
  end
end
