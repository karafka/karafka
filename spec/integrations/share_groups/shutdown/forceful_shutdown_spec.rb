# frozen_string_literal: true

# Share group (KIP-932): when the server is stopped while a share consumer hangs, it should force
# a shutdown (exit code 2) reporting the active share listener, alive workers and the share
# consume job still in processing.

setup_karafka(allow_errors: true) do |config|
  config.shutdown_timeout = 1_000
  config.max_wait_time = 500
end

# Redirect logger to a StringIO so we can assert on log output
log_io = StringIO.new
Karafka.logger.reopen(log_io)

class Consumer < Karafka::ShareConsumer
  def consume
    DT[0] << true
    # This will "fake" a hanging job
    sleep(100)
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
    end
  end
end

setup_share_group

produce(DT.topic, "1")

Karafka.monitor.subscribe("error.occurred") do |event|
  next unless event[:type] == "app.stopping.error"

  active_listeners = event.payload[:active_listeners]
  in_processing = event.payload[:in_processing]

  assert !active_listeners.empty?
  assert(active_listeners.all? { |listener| listener.is_a?(Karafka::Connection::ShareGroups::Listener) })
  assert !event.payload[:alive_workers].empty?

  jobs = in_processing.values.flatten

  assert(jobs.any? { |job| job.is_a?(Karafka::Processing::ShareGroups::Jobs::Consume) })

  log_output = log_io.string

  assert log_output.include?("Forceful Karafka server stop")
  assert log_output.include?("still active")
  assert log_output.include?("In processing: Consume job for #{DT.topic}/0")
end

start_karafka_and_wait_until do
  if DT[0].empty?
    false
  else
    sleep 1
    true
  end
end

# Karafka is expected to exit with 2 from a different thread, so we just block here
sleep
