module SimcovAiFormatter
  class Error < StandardError; end
  class ResultsetNotFound < Error; end
  class InvalidResultset < Error; end
  class SuiteNotFound < Error; end
end
