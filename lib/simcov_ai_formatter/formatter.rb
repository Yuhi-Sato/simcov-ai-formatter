require "pathname"

module SimcovAiFormatter
  # Transforms SimpleCov's coverage hash into the AI-friendly Hash shape.
  #
  # Input:  { "<abs_path>" => { "lines" => [null|0|N, ...], "branches" => {...}? } }
  # Output: see README for the full schema.
  class Formatter
    # @param coverage [Hash{String => Hash}] SimpleCov-shaped coverage hash.
    #   Keys are absolute file paths. Each value has:
    #     - "lines" [Array<Integer, nil>] zero-indexed; element at index i is the
    #       hit count for line (i + 1). nil = non-relevant line (comment/blank),
    #       0 = missed, positive Integer = hit count.
    #     - "branches" [Hash, nil] optional. Outer keys are line-number strings,
    #       inner keys are branch labels ("then" / "else" / ...), values are
    #       Integer hit counts.
    # @param suite [String] display label for the suite (e.g. "RSpec", "merged")
    # @param root [String, Pathname] base directory for relativizing file paths
    # @param suites_merged [Array<String>, nil] original suite names when multiple
    #   suites were merged; omitted from the output when fewer than 2 entries
    # @param with_source [Boolean] embed source snippets around uncovered ranges
    # @param context [Integer] number of context lines around uncovered ranges
    #   when with_source is true
    # @param source_reader [SourceReader, nil] source provider; required when
    #   with_source is true, otherwise unused
    def initialize(coverage:, suite:, root:, suites_merged: nil, with_source: false, context: 2, source_reader: nil)
      @coverage = coverage
      @suite = suite
      @suites_merged = suites_merged
      @root = Pathname.new(root).expand_path
      @with_source = with_source
      @context = context
      @source_reader = source_reader
    end

    # @return [Hash] AI-friendly report. Top-level keys:
    #   - "schema_version" [Integer]
    #   - "suite" [String]
    #   - "root" [String] absolute path to the relativization base
    #   - "summary" [Hash] aggregated counts: "total_files", "relevant_lines",
    #     "covered_lines", "missed_lines", "coverage_percentage"
    #   - "files" [Hash{String => Hash}] keyed by relative path; each entry has
    #     "relevant_lines", "covered_lines", "missed_lines",
    #     "coverage_percentage", "uncovered_ranges", "uncovered_lines",
    #     and optionally "branches_raw" when branch data is present
    #   - "suites_merged" [Array<String>] only present when more than one suite
    #     was merged
    def call
      files = build_files
      project_summary = aggregate_summary(files)

      result = {
        "schema_version" => 1,
        "suite" => @suite,
        "root" => @root.to_s,
        "summary" => project_summary,
        "files" => files
      }
      if @suites_merged && @suites_merged.size > 1
        result["suites_merged"] = @suites_merged
      end
      result
    end

    private

    def build_files
      sorted = @coverage.keys.sort
      sorted.each_with_object({}) do |abs_path, acc|
        entry = @coverage[abs_path]
        rel = relativize(abs_path)
        acc[rel] = build_file_entry(abs_path, entry)
      end
    end

    def build_file_entry(abs_path, entry)
      lines = entry["lines"] || []
      relevant = lines.count { |v| !v.nil? }
      covered = lines.count { |v| v.is_a?(Integer) && v.positive? }
      uncovered_lines = find_uncovered_lines(lines)
      uncovered_ranges = collapse_ranges(uncovered_lines)

      file_entry = {
        "relevant_lines" => relevant,
        "covered_lines" => covered,
        "missed_lines" => relevant - covered,
        "coverage_percentage" => percentage(covered, relevant),
        "uncovered_ranges" => uncovered_ranges,
        "uncovered_lines" => uncovered_lines
      }

      with_source_attached = @with_source && @source_reader && !uncovered_ranges.empty?
      if with_source_attached
        file_entry["uncovered_ranges"] = uncovered_ranges.map do |range|
          attach_source(abs_path, range, lines)
        end
      end

      attach_branches(file_entry, entry)
      file_entry
    end

    def find_uncovered_lines(lines)
      lines.each_with_index.filter_map { |v, i| i + 1 if v.is_a?(Integer) && v.zero? }
    end

    def attach_branches(file_entry, entry)
      branches = entry["branches"]
      file_entry["branches_raw"] = branches if branches.is_a?(Hash) && !branches.empty?
    end

    def attach_source(abs_path, range, lines)
      start_line = [range["start"] - @context, 1].max
      end_line = range["end"] + @context
      snippet = @source_reader.read(abs_path, start_line, end_line)

      if snippet.nil?
        range.merge("source" => nil, "source_error" => "missing")
      else
        source_array = snippet.map do |line_no, text|
          {
            "line" => line_no,
            "text" => text,
            "covered" => covered_for(lines[line_no - 1])
          }
        end
        range.merge("source" => source_array)
      end
    end

    def covered_for(value)
      return nil if value.nil?
      return false if value.is_a?(Integer) && value.zero?
      true
    end

    def collapse_ranges(line_numbers)
      ranges = []
      line_numbers.each do |n|
        if !ranges.empty? && ranges.last["end"] == n - 1
          ranges.last["end"] = n
        else
          ranges << { "start" => n, "end" => n }
        end
      end
      ranges
    end

    def aggregate_summary(files)
      values = files.values
      total_relevant = values.sum { |f| f["relevant_lines"] }
      total_covered = values.sum { |f| f["covered_lines"] }
      total_missed = values.sum { |f| f["missed_lines"] }
      {
        "total_files" => files.size,
        "relevant_lines" => total_relevant,
        "covered_lines" => total_covered,
        "missed_lines" => total_missed,
        "coverage_percentage" => percentage(total_covered, total_relevant)
      }
    end

    def percentage(covered, relevant)
      return 100.0 if relevant.zero?
      (covered.to_f / relevant * 100).round(2)
    end

    def relativize(abs_path)
      pathname = Pathname.new(abs_path)
      return "!abs:#{abs_path}" unless pathname.absolute?

      begin
        relative = pathname.relative_path_from(@root).to_s
        if relative.start_with?("..")
          "!abs:#{abs_path}"
        else
          relative
        end
      rescue ArgumentError
        "!abs:#{abs_path}"
      end
    end
  end
end
