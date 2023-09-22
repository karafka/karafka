# frozen_string_literal: true

# In case there are not enough threads to parallelize work from multiple topics/partitions we can
# expect a processing lag, as work will wait in a queue to be picked up once resources are
# available

setup_karafka do |config|
  config.max_messages = 1_000
  config.concurrency = 1
  config.kafka[:'fetch.message.max.bytes'] = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.2)
    DT[:topics] << messages.metadata.topic
    DT[:processing_lags] << messages.metadata.processing_lag
  end
end

draw_routes do
  names = []

  DT.topics.first(2).each do |topic_name|
    names << topic_name

    topic topic_name do
      consumer Consumer
    end
  end

  5.times do
    names.each do |topic_name|
      # Dispatching in a loop per topic will ensure the delivery order
      produce_many(topic_name, DT.uuids(4))
    end
  end
end

start_karafka_and_wait_until do
  DT[:processing_lags].size >= 2 && DT[:topics].uniq.size >= 2
end

max_lag = DT[:processing_lags].max

assert (200..400).cover?(max_lag), max_lag
