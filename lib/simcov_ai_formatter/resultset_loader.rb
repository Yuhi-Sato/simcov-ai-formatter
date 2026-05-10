require "json"

module SimcovAiFormatter
  # Loads SimpleCov's .resultset.json, validates its shape, and returns the parsed Hash.
  #
  # Expected shape:
  #   {
  #     "<suite_name>" => {
  #       "coverage" => { "<abs_path>" => { "lines" => [...], "branches" => {...} } },
  #       "timestamp" => Integer
  #     },
  #     ...
  #   }
  class ResultsetLoader
    # @param path [String] path to SimpleCov resultset.json
    def initialize(path)
      @path = path
    end

    # @return [Hash] parsed resultset; see class comment for shape
    # @raise [ResultsetNotFound] if the file does not exist
    # @raise [InvalidResultset] if JSON is malformed or structurally invalid
    def load
      raw = read_json
      validate!(raw)
      raw
    end

    private

    def read_json
      unless File.exist?(@path)
        raise ResultsetNotFound, "resultset.json not found: #{@path}"
      end

      JSON.parse(File.read(@path))
    rescue JSON::ParserError => e
      raise InvalidResultset, "invalid JSON at #{@path}: #{e.message}"
    end

    def validate!(raw)
      unless raw.is_a?(Hash) && !raw.empty?
        raise InvalidResultset, "expected non-empty top-level hash at #{@path}"
      end

      raw.each { |suite, body| validate_suite!(suite, body) }
    end

    def validate_suite!(suite, body)
      unless body.is_a?(Hash) && body["coverage"].is_a?(Hash)
        raise InvalidResultset, "suite #{suite.inspect} missing 'coverage' hash"
      end

      body["coverage"].each { |file, entry| validate_file!(suite, file, entry) }
    end

    def validate_file!(suite, file, entry)
      unless entry.is_a?(Hash) && entry["lines"].is_a?(Array)
        raise InvalidResultset, "file #{file.inspect} in suite #{suite.inspect} missing 'lines' array"
      end
    end
  end
end
