# frozen_string_literal: true

# Karafka should publish same number of consumed events as batches consumed
# We also should track the assignments correctly

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:assignments] = Karafka::App.assignments

    DT[0] << messages.size
  end
end

Karafka::App.monitor.subscribe("consumer.consume") do |event|
  DT[2] << event[:caller].messages.size
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
  DT[0].sum >= 100
end

assert_equal DT[0], DT[1]
assert_equal DT[1], DT[2]

# Make sure that we have detected proper assignments
assert_equal DT[:assignments].keys.first.name, DT.topic
assert_equal [0], DT[:assignments].values.first

# Last state after shutdown should indicate no assignments
assert Karafka::App.assignments.empty?
