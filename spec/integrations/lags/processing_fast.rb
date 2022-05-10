# frozen_string_literal: true

# When processing data fast, the processing lag should not be big and things should be processed
# almost real time

setup_karafka do |config|
  config.max_messages = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
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
