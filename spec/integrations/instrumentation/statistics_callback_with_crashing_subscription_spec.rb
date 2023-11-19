# frozen_string_literal: true

# Karafka should not hang or crash when we receive the statistics processing error. It should
# recover and be responsive.

setup_karafka(allow_errors: true)

Consumer = Class.new(Karafka::BaseConsumer)

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

class Listener
  def on_statistics_emitted(event)
    DT[:statistics_events] << event

    raise StandardError
  end

  def on_error_occurred(event)
    DT[:error_events] << event
  end
end

Karafka::App.monitor.subscribe(Listener.new)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:statistics_events].size >= 5 && DT[:error_events].size >= 5
end

p DT[:error_events].count
