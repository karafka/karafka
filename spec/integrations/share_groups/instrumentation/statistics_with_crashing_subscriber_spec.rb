# frozen_string_literal: true

# Share group (KIP-932) should not hang or crash when a statistics subscriber raises. The error is
# reported and the share group keeps consuming.

setup_karafka(allow_errors: %w[callbacks.statistics.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
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

share_sg = Karafka::App.subscription_groups.values.flatten.find { |sg| sg.group.share_group? }

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:statistics_events].size >= 5 &&
    DT[:error_events].size >= 5 &&
    DT[:accepted].size >= 100
end

assert_equal elements.sort, DT[:accepted].sort

DT[:error_events].each do |event|
  assert_equal "callbacks.statistics.error", event[:type]
  assert_equal share_sg.id, event[:subscription_group_id]
end
