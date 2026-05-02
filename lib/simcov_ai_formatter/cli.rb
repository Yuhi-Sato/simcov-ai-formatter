require "optparse"

module SimcovAiFormatter
  class CLI
    EXIT_OK = 0
    EXIT_USER_ERROR = 1
    EXIT_INTERNAL_ERROR = 2

    def initialize(argv, stdout: $stdout, stderr: $stderr)
      @argv = argv.dup
      @stdout = stdout
      @stderr = stderr
      @options = {
        output: nil,
        root: Dir.pwd,
        suite: nil,
        with_source: false,
        context: 2,
        pretty: false
      }
    end

    def run
      parser = build_parser
      remaining = parser.parse(@argv)
      resultset_path = remaining.first || DEFAULT_RESULTSET_PATH

      source_warnings = @options[:with_source] ? @stderr : nil
      raw = ResultsetLoader.new(resultset_path).load
      selected_suite, coverage = SuiteMerger.new(raw, suite: @options[:suite]).select
      source_reader = @options[:with_source] ? SourceReader.new(warnings: source_warnings) : nil

      result = Formatter.new(
        coverage: coverage,
        suite: selected_suite,
        suites_merged: @options[:suite].nil? ? raw.keys : nil,
        root: @options[:root],
        with_source: @options[:with_source],
        context: @options[:context],
        source_reader: source_reader
      ).call

      source_reader&.report_missing

      output = Renderer.new(pretty: @options[:pretty]).render(result)

      if @options[:output]
        File.write(@options[:output], output + "\n")
      else
        @stdout.puts(output)
      end

      EXIT_OK
    rescue ResultsetNotFound, InvalidResultset, SuiteNotFound, OptionParser::ParseError => e
      @stderr.puts("simcov-ai-formatter: error: #{e.message}")
      EXIT_USER_ERROR
    rescue StandardError => e
      @stderr.puts("simcov-ai-formatter: internal error: #{e.class}: #{e.message}")
      @stderr.puts(e.backtrace.first(5).map { |l| "  #{l}" }) if ENV["SIMCOV_AI_DEBUG"]
      EXIT_INTERNAL_ERROR
    end

    private

    def build_parser
      OptionParser.new do |opts|
        opts.banner = "Usage: simcov-ai-formatter [RESULTSET_PATH] [options]"
        opts.separator ""
        opts.separator "Options:"

        opts.on("-o", "--output PATH", "Output file path (default: stdout)") { |v| @options[:output] = v }
        opts.on("--root PATH", "Base directory for relative paths (default: cwd)") { |v| @options[:root] = v }
        opts.on("--suite NAME", "Pick a single suite (default: merge all suites with max(hit))") { |v| @options[:suite] = v }
        opts.on("--with-source", "Embed source lines around uncovered ranges") { @options[:with_source] = true }
        opts.on("--context N", Integer, "Lines of context when --with-source is set (default: 2)") { |v| @options[:context] = v }
        opts.on("--pretty", "Pretty-print JSON (default: minified)") { @options[:pretty] = true }

        opts.on("-v", "--version", "Print version") do
          @stdout.puts(VERSION)
          exit EXIT_OK
        end

        opts.on("-h", "--help", "Show this help") do
          @stdout.puts(opts)
          exit EXIT_OK
        end
      end
    end
  end
end
