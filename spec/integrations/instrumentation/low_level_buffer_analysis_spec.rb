# frozen_string_literal: true

# We should be able to inject a low level monitor for ensuring, that there are no duplicates in
# the data received from rdkafka

Karafka::App.monitor.subscribe("connection.listener.fetch_loop.received") do |event|
  event[:messages_buffer].each do |_topic_name, _partition, messages|
    assert_equal [1], messages.group_by(&:offset).transform_values(&:size).values.uniq
  end
end

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT.key?(0)
end
