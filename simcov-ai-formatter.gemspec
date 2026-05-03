require_relative "lib/simcov_ai_formatter/version"

Gem::Specification.new do |spec|
  spec.name = "simcov-ai-formatter"
  spec.version = SimcovAiFormatter::VERSION
  spec.authors = ["Yuhi Sato"]
  spec.email = ["yuhi_sato@smartbank.co.jp"]

  spec.summary = "Format SimpleCov coverage data into AI-friendly JSON (formatter plugin + CLI)"
  spec.description = "Converts SimpleCov coverage data into a JSON format optimized for LLM/AI consumption — per-file summaries, uncovered ranges, optional source snippets. Works as a SimpleCov formatter plugin (auto-emit during test runs) or as a CLI on an existing .resultset.json."
  spec.homepage = "https://github.com/y-sato/simcov-ai-formatter"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*.rb",
    "exe/*",
    "README.md",
    "LICENSE.txt",
    "CHANGELOG.md"
  ]
  spec.bindir = "exe"
  spec.executables = ["simcov-ai-formatter"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
