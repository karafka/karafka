# frozen_string_literal: true

# This test demonstrates the "good" scenario: a long-running Karafka consumer embedded in Puma
# checks Karafka::App.stopping? between processing chunks and breaks out early when Puma
# triggers shutdown.
#
# Because the consumer exits its processing loop promptly, Karafka::Embedded.stop completes
# within Puma's worker_shutdown_timeout and the worker shuts down gracefully (no SIGKILL).
#
# The offset is NOT committed on early exit, so a new worker instance would pick up the
# unfinished message and resume processing — ensuring no data loss.
#
# A consumer that processes large parquet log drops (400k entries) should check stopping? between
# batches and break early if Karafka is shutting down.

Bundler.require(:default)

shutdown_file = File.join(__dir__, "shutdown.txt")
result_file = File.join(__dir__, "result.txt")
[shutdown_file, result_file].each { |f| File.delete(f) if File.exist?(f) }

system("bundle exec ruby config/app.rb -s puma")

status = $CHILD_STATUS

# Read the files to verify graceful shutdown with early exit
result = File.exist?(result_file) ? File.read(result_file) : "no_result"
shutdown_result = File.exist?(shutdown_file) ? File.read(shutdown_file) : "no_shutdown_file"

# Clean up
[shutdown_file, result_file].each { |f| File.delete(f) if File.exist?(f) }

# Verify:
# 1. Puma exited via SIGTERM (15), NOT via SIGKILL — graceful shutdown worked
# 2. The consumer performed an early exit (not a full completion)
# 3. The shutdown hook completed successfully (not SIGKILL'd)
graceful_exit = status.to_i == 15
early_exit = result.start_with?("early_exit:")
shutdown_completed = shutdown_result.include?("shutdown_hook_finished")

exit (graceful_exit && early_exit && shutdown_completed) ? 0 : 1
