# frozen_string_literal: true

# Karafka console in a non-Rails app with irb in the Gemfile should start with the app booted.

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

output, code = run(
  "bundle exec karafka console",
  "puts \"CONSOLE_STARTED \#{Karafka::App.routes.size}\"\nexit\n"
)

raise "Expected the console to start (#{code}): #{output}" unless code.zero?
raise "Expected the app to be booted: #{output}" unless output.include?("CONSOLE_STARTED 1")
raise "Expected no irb hint: #{output}" if output.include?("needs the irb gem")
