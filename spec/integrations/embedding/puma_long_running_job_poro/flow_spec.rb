# frozen_string_literal: true

# This test demonstrates the "ugly" scenario: a long-running Karafka consumer embedded in Puma
# blocks the worker shutdown. Because processing takes longer than Puma's worker_shutdown_timeout,
# Puma master sends SIGKILL to the worker.
#
# The key issue: Karafka::Embedded.stop is blocking (it waits for App.terminated?), but the
# consumer's #consume method is stuck in a long loop without checking Karafka::App.stopping?.
# Puma master cannot wait forever and kills the worker.
#
# When processing a single Kafka message that represents a large parquet log drop (400k entries)
# takes 200+ seconds, it exceeds Puma's allowed shutdown window.

Bundler.require(:default)

shutdown_file = File.join(__dir__, "shutdown.txt")
result_file = File.join(__dir__, "result.txt")
[shutdown_file, result_file].each { |f| File.delete(f) if File.exist?(f) }

system("bundle exec ruby config/app.rb -s puma")

status = $CHILD_STATUS

# Read the shutdown file to verify the worker was SIGKILL'd during shutdown
shutdown_result = File.exist?(shutdown_file) ? File.read(shutdown_file) : "no_shutdown_file"

# Clean up
[shutdown_file, result_file].each { |f| File.delete(f) if File.exist?(f) }

# Verify:
# 1. Puma master exited via SIGTERM (15) — our test trigger
# 2. The shutdown hook started but never finished — proving the worker was SIGKILL'd
puma_exited_cleanly = status.to_i == 15
worker_was_killed = shutdown_result.start_with?("shutdown_hook_started:") &&
  !shutdown_result.include?("shutdown_hook_finished")

exit (puma_exited_cleanly && worker_was_killed) ? 0 : 1
