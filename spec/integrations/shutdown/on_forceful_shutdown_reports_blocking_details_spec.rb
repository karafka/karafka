# frozen_string_literal: true

# When Karafka forcefully terminates due to a hanging consumer, the app.stopping.error event
# should include details about what was blocking: active listeners, alive workers, and jobs
# still in processing. The logger listener should also output these details.

setup_karafka(allow_errors: true) do |config|
  config.shutdown_timeout = 1_000
  config.max_wait_time = 500
end

# Redirect logger to a StringIO so we can assert on log output
log_io = StringIO.new
Karafka.logger.reopen(log_io)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
    # This will "fake" a hanging job just long enough to exceed the short shutdown timeout
    sleep(5)
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

Karafka.monitor.subscribe("error.occurred") do |event|
  next unless event[:type] == "app.stopping.error"

  # The event should include detailed blocking information
  active_listeners = event.payload[:active_listeners]
  alive_workers = event.payload[:alive_workers]
  in_processing = event.payload[:in_processing]

  assert active_listeners.is_a?(Array), "active_listeners should be an Array"
  assert alive_workers.is_a?(Array), "alive_workers should be an Array"
  assert in_processing.is_a?(Hash), "in_processing should be a Hash"

  assert !active_listeners.empty?, "Expected at least one active listener"
  assert !alive_workers.empty?, "Expected at least one alive worker"
  assert !in_processing.empty?, "Expected at least one group with in-processing jobs"

  all_jobs = in_processing.values.flatten

  assert !all_jobs.empty?, "Expected at least one job in processing"

  consume_jobs = all_jobs.select { |job| job.is_a?(Karafka::Processing::Jobs::Consume) }

  assert !consume_jobs.empty?, "Expected at least one Consume job still in processing"

  # Verify the logger listener produced the expected output
  log_output = log_io.string

  assert log_output.include?("Forceful Karafka server stop"), "Expected forceful stop message in logs"
  assert log_output.include?("active workers"), "Expected active workers count in logs"
  assert log_output.include?("active listeners"), "Expected active listeners count in logs"
  assert log_output.include?("still active"), "Expected listener details in logs"
  assert log_output.include?("In processing:"), "Expected in-processing job details in logs"
  assert log_output.include?("Consume"), "Expected Consume job type in logs"

  DT[:assertions_passed] << true
end

start_karafka_and_wait_until do
  if DT[0].empty?
    false
  else
    sleep 1
    true
  end
end

# This sleep is not a problem. Since Karafka runs in a background thread and in this scenario is
# suppose to exit with 2 from a different thread, we just block it so Karafka has time to actually
# end the process as expected
sleep
