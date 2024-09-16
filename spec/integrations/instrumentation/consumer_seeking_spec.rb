# frozen_string_literal: true

# We should be able to instrument seeking

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:messages] << messages.first.offset

    seek(0)
  end
end

draw_routes(Consumer)

Karafka::App.monitor.subscribe('consumer.consuming.seek') do |event|
  DT[:seeks] << event
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT[:messages].size >= 5
end

assert_equal DT[:messages].uniq, [0]
assert DT[:seeks].count >= 4

assert DT[:seeks].first[:caller].is_a?(Consumer)
assert_equal DT[:seeks].first[:topic], DT.topic
assert_equal DT[:seeks].first[:message].offset, 0
