# frozen_string_literal: true

# If post-error instrumentation re-raises the error so it bubbles up to the worker, it will crash
# and karafka should stop. Since an endless bubbling error cannot be rescued, it will force
# Karafka to move into a forceful shutdown.

setup_karafka(allow_errors: true) do |config|
  config.shutdown_timeout = 5_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end
end

draw_routes(Consumer)

# We do not crash on the forceful shutdown error as this layer needs to correctly close librdkafka
# consumers, otherwise it may segfault
Karafka::App.monitor.subscribe('error.occurred') do |event|
  raise if event[:caller].is_a?(Karafka::BaseConsumer)
  raise if event[:caller].is_a?(Karafka::Processing::Worker)
end

produce_many(DT.topic, DT.uuids(1))

begin
  start_karafka_and_wait_until do
    false
  end

  # This should never be reached
  exit 10
rescue StandardError
  Karafka::Server.stop

  exit 1
end

sleep(1)

exit 10
