# frozen_string_literal: true

# When weird things happen with partition (it disappears), Karafka receives weird metadata, etc
# we should be able to detect this and gracefully shutdown
#
# For any reason, especially affected is MSK during rolling updates.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'allow.auto.create.topics'] = false
end

Karafka.monitor.subscribe('error.occurred') do |event|
  next unless event[:error].is_a?(Rdkafka::RdkafkaError)
  next unless event[:error].code == :unknown_partition

  Process.kill('TERM', Process.pid)
end

class Consumer < Karafka::BaseConsumer
  def consume
    mark_as_consumed!(messages.first)

    DT[:running] = true
    sleep(0.1) until DT.key?(:recreated)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 5)
  end
end

elements = DT.uuids(10)
produce_many(DT.topic, elements)

Thread.new do
  sleep(0.1) until DT.key?(:running)

  Karafka::Admin.delete_topic(DT.topic)
  Karafka::Admin.create_topic(DT.topic, 1, 1)

  DT[:recreated] = true
end

start_karafka_and_wait_until do
  DT[0].size >= 100
end
