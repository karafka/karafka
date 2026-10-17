# frozen_string_literal: true

# Karafka console in a non-Rails app whose Gemfile has no irb should, on Ruby 4.0+ (where irb is
# a bundled gem), explain how to add irb instead of failing with a Bundler error. On older Rubies
# irb is a default gem, so the console should start.

require "open3"

# Runs a command in the current (scenario) directory
# @param cmd [String]
# @param stdin [String]
# @return [Array<String, Integer>] combined output and exit code
def run(cmd, stdin = "")
  stdout, stderr, status = Open3.capture3(cmd, stdin_data: stdin)
  ["#{stdout}\n#{stderr}", status.exitstatus]
end

output, code = run("bundle exec karafka install")
raise "karafka install failed (#{code}): #{output}" unless code.zero?

output, code = run("bundle exec karafka console", "puts \"CONSOLE_STARTED\"\nexit\n")

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("4.0")
  raise "Expected exit code 1, got #{code}: #{output}" unless code == 1
  raise "Expected the irb hint: #{output}" unless output.include?('Add `gem "irb"` to your Gemfile')
  raise "Expected no Bundler error: #{output}" if output.include?("Gem::Exception")
else
  raise "Expected the console to start (#{code}): #{output}" unless code.zero?
  raise "Expected the console to start: #{output}" unless output.include?("CONSOLE_STARTED")
end
