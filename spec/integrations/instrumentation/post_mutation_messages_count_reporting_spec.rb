# frozen_string_literal: true

# When we mutate the messages batch size, it should not impact the instrumentation
# Alongside that, because we use auto-offset management, it also should not crash as it should
# use original messages references.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.to_a.clear
  end
end

Karafka::App.monitor.subscribe("consumer.consume") do |event|
  DT[0] << event[:caller].messages.size
end

Karafka::App.monitor.subscribe("consumer.consumed") do |event|
  DT[1] << event[:caller].messages.size
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

start_karafka_and_wait_until do
  produce(DT.topic, rand.to_s)
  DT[0].size >= 10 && DT[1].size >= 10
end

assert_equal DT[0].sum, DT[1].sum
