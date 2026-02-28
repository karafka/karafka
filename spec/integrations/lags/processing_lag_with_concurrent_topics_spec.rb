# frozen_string_literal: true

# Processing lag measured across multiple topics consumed concurrently should show
# that when threads are constrained, one topic may experience higher processing lag
# than another.

setup_karafka do |config|
  config.max_messages = 10
  config.concurrency = 1
  config.kafka[:"fetch.message.max.bytes"] = 1
  config.max_wait_time = 5_000
end

Karafka.monitor.subscribe("connection.listener.fetch_loop.received") do |event|
  total = 0

  event[:messages_buffer].each do |_topic, _partition, _messages|
    total += 1
  end

  DT[:both] = true if total >= 2
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.2)
    DT[:topics] << messages.metadata.topic
    DT[:processing_lags] << messages.metadata.processing_lag
  end
end

draw_routes do
  DT.topics.first(2).each do |topic_name|
    topic topic_name do
      consumer Consumer
    end
  end
end

Thread.new do
  loop do
    DT.topics.first(2).each do |topic_name|
      produce(topic_name, DT.uuids(10).first)
    end

    sleep(0.1)
  rescue WaterDrop::Errors::ProducerClosedError
    break
  end
end

start_karafka_and_wait_until do
  DT[:processing_lags].size >= 2 && DT[:topics].uniq.size >= 2 && DT.key?(:both)
end

max_lag = DT[:processing_lags].max

assert (200..600).cover?(max_lag), "Processing lag: #{max_lag}"
