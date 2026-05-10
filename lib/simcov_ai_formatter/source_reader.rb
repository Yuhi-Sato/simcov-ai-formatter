module SimcovAiFormatter
  # Reads source files by 1-indexed line numbers with random access.
  # Files are cached as line arrays after the first read.
  # Missing files and unknown encodings never crash the caller.
  class SourceReader
    # @param warnings [IO, nil] destination for missing-source warnings;
    #   nil disables warnings
    def initialize(warnings: nil)
      @cache = {}
      @missing = []
      @warnings = warnings
    end

    # @param path [String] absolute path to the source file
    # @param start_line [Integer] inclusive 1-indexed start line; clamped to >= 1
    # @param end_line [Integer] inclusive 1-indexed end line; clamped to file size
    # @return [Array<[Integer, String]>, nil] line-number/text pairs, or nil if the file is missing
    def read(path, start_line, end_line)
      lines = lines_for(path)
      return nil if lines.nil?

      from = [start_line, 1].max
      to = [end_line, lines.size].min
      (from..to).map { |n| [n, lines[n - 1]] }
    end

    # Writes a summary of missing source files (up to 5 listed) to the
    # configured warnings IO. No-op when warnings is nil or no files were missing.
    # @return [void]
    def report_missing
      return if @warnings.nil? || @missing.empty?
      @warnings.puts("simcov-ai-formatter: warning: #{@missing.size} source file(s) not found:")
      @missing.first(5).each { |p| @warnings.puts("  - #{p}") }
      @warnings.puts("  ...") if @missing.size > 5
    end

    private

    def lines_for(path)
      return @cache[path] if @cache.key?(path)

      unless File.exist?(path)
        @missing << path
        return (@cache[path] = nil)
      end

      @cache[path] = read_lines_safely(path)
    end

    def read_lines_safely(path)
      raw = File.read(path, mode: "rb")
      text = raw.force_encoding("UTF-8")
      text = text.scrub("?") unless text.valid_encoding?
      text.split(/\r\n|\r|\n/, -1).tap { |arr| arr.pop if arr.last == "" }
    end
  end
end
