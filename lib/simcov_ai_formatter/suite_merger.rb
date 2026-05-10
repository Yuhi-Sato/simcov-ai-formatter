module SimcovAiFormatter
  # Merges multiple suites in a resultset into a single coverage Hash,
  # or selects one when --suite NAME is given.
  #
  # Line merge rules per (file, index):
  #   - one nil and one Integer → take the Integer
  #   - both Integer            → take max(hit)
  #   - both nil                → nil
  # Branches: hit counts are summed for matching keys; missing keys are added.
  class SuiteMerger
    # @param resultset [Hash] parsed resultset shaped as
    #   `{ suite_name => { "coverage" => Hash, "timestamp" => Integer } }`.
    #   See class comment for the full shape.
    # @param suite [String, nil] pick this suite only; nil means merge all suites.
    def initialize(resultset, suite: nil)
      @resultset = resultset
      @suite = suite
    end

    # @return [Array(String, Hash)] tuple of [suite label, coverage hash matching
    #   the shape of Formatter#initialize's coverage arg]
    def select
      return select_specified_suite if @suite
      return select_sole_suite if @resultset.size == 1
      select_merged_suites
    end

    private

    def select_specified_suite
      body = @resultset[@suite]
      unless body
        available = @resultset.keys.join(", ")
        raise SuiteNotFound, "suite #{@suite.inspect} not in resultset (available: #{available})"
      end
      [@suite, body["coverage"]]
    end

    def select_sole_suite
      suite, body = @resultset.first
      [suite, body["coverage"]]
    end

    def select_merged_suites
      ["merged", merge_all]
    end

    def merge_all
      merged = {}
      @resultset.each_value do |body|
        body["coverage"].each do |file, entry|
          if merged.key?(file)
            merged[file] = merge_entries(merged[file], entry)
          else
            merged[file] = deep_dup(entry)
          end
        end
      end
      merged
    end

    def merge_entries(a, b)
      lines_a = a["lines"]
      lines_b = b["lines"]
      length = [lines_a.size, lines_b.size].max
      merged_lines = Array.new(length) do |i|
        merge_hit(lines_a[i], lines_b[i])
      end

      result = { "lines" => merged_lines }
      branches_a = a["branches"]
      branches_b = b["branches"]
      if branches_a || branches_b
        result["branches"] = merge_branches(branches_a, branches_b)
      end
      result
    end

    def merge_hit(x, y)
      return y if x.nil?
      return x if y.nil?
      [x, y].max
    end

    def merge_branches(a, b)
      a ||= {}
      b ||= {}
      keys = (a.keys | b.keys)
      keys.each_with_object({}) do |outer_key, acc|
        acc[outer_key] = sum_branch_hits(a[outer_key] || {}, b[outer_key] || {})
      end
    end

    def sum_branch_hits(inner_a, inner_b)
      inner_keys = (inner_a.keys | inner_b.keys)
      inner_keys.each_with_object({}) do |k, sub|
        sub[k] = (inner_a[k] || 0) + (inner_b[k] || 0)
      end
    end

    def deep_dup(entry)
      JSON.parse(JSON.generate(entry))
    end
  end
end
