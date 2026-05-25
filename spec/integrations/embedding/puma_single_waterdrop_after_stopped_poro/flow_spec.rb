# frozen_string_literal: true

# Regression test for https://github.com/karafka/waterdrop/issues/866
#
# Puma's `after_stopped` hook in single mode runs in a Ruby signal trap context.
# WaterDrop::Producer#close must not raise ThreadError when called from there.

Bundler.require(:default)

result_file = File.join(__dir__, "result.txt")
File.delete(result_file) if File.exist?(result_file)

system("bundle exec ruby config/app.rb -s puma")

result = File.exist?(result_file) ? File.read(result_file) : "no_result_file"
File.delete(result_file) if File.exist?(result_file)

unless result == "success"
  warn "Expected producer.close to succeed from after_stopped, got: #{result}"
  exit 1
end

exit 0
