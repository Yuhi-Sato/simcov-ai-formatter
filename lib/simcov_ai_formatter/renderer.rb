require "json"

module SimcovAiFormatter
  class Renderer
    # @param pretty [Boolean] whether to pretty-print the JSON output
    def initialize(pretty: false)
      @pretty = pretty
    end

    # @param hash [Hash] structure to serialize; typically the result of Formatter#call
    # @return [String] JSON encoding of hash
    def render(hash)
      @pretty ? JSON.pretty_generate(hash) : JSON.generate(hash)
    end
  end
end
