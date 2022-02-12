# frozen_string_literal: true

# In case there are not enough threads to parallelize work from multiple topics/partitions we can
# expect a processing lag, as work will wait in a queue to be picked up once resources are
# available

setup_karafka do |config|
  config.max_messages = 1_000
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.2)
    DataCollector.data[:processing_lags] << messages.metadata.processing_lag
  end
end

draw_routes do
  consumer_group DataCollector.consumer_group do
    DataCollector.topics.first(2).each do |topic_name|
      topic topic_name do
        consumer Consumer
      end

      # Dispatching in a loop per topic will ensure the delivery order
      20.times { produce(topic_name, SecureRandom.uuid) }
    end
  end
end

start_karafka_and_wait_until do
  DataCollector.data[:processing_lags].size >= 2
end

max_lag = DataCollector.data[:processing_lags].max

assert_equal true, (200..300).cover?(max_lag)
