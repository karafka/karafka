# frozen_string_literal: true

# Share group (KIP-932) consumers can scale the workers pool up and down from within `#consume`
# and consumption continues on the resized pool without losing any records.

setup_karafka do |config|
  config.concurrency = 2
end

Karafka.monitor.subscribe("worker.scaling.up") do |event|
  DT[:scale_up_events] << [event.payload[:from], event.payload[:to]]
end

Karafka.monitor.subscribe("worker.scaling.down") do |event|
  DT[:scale_down_events] << [event.payload[:from], event.payload[:to]]
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end

    if !DT.key?(:scaled_up)
      DT[:size_before] = Karafka::Server.workers.size
      Karafka::Server.workers.scale(5)
      DT[:size_after_up] = Karafka::Server.workers.size
      DT[:scaled_up] = true
    elsif !DT.key?(:scaled_down)
      Karafka::Server.workers.scale(3)
      sleep(2)
      DT[:size_after_down] = Karafka::Server.workers.size
      DT[:scaled_down] = true
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

elements = []

# Produce in rounds, so we get several batches
start_karafka_and_wait_until do
  if DT[:accepted].size == elements.size && elements.size < 30
    batch = DT.uuids(10)
    elements += batch
    produce_many(DT.topic, batch)
  end

  DT[:accepted].size >= 30
end

assert_equal elements.sort, DT[:accepted].sort
assert_equal 2, DT[:size_before]
assert_equal 5, DT[:size_after_up]
assert_equal 3, DT[:size_after_down]
assert_equal [[0, 2], [2, 5]], DT[:scale_up_events]
assert_equal [[5, 3]], DT[:scale_down_events]
