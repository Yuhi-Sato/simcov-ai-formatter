require "json"

module SimcovAiFormatter
  class Renderer
    def initialize(pretty: false)
      @pretty = pretty
    end

    def render(hash)
      @pretty ? JSON.pretty_generate(hash) : JSON.generate(hash)
    end
  end
end
