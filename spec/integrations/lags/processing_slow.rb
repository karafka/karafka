# frozen_string_literal: true

# When processing data slowly from a single partition of a single topic, we do not fetch more data
# from Kafka, thus the processing lag should not be big as there is no more data enqueued
# We keep the time numbers a bit higher than they could be as when running on the CI, sometimes
# there are small lags

setup_karafka do |config|
  config.max_messages = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.1)
    DataCollector.data[:processing_lags] << messages.metadata.processing_lag
  end
end

draw_routes(Consumer)

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector.data[:processing_lags].size >= 20
end

assert_equal true, DataCollector.data[:processing_lags].max <= 50
