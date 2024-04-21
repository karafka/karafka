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

Karafka::App.monitor.subscribe('error.occurred') do
  raise
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  false
end
