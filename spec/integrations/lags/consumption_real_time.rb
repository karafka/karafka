# frozen_string_literal: true

# Karafka should correctly report consumption_lag when we consume messages fast and it should never
# be bigger than couple hundred ms with the defaults for integration specs

setup_karafka

elements = Array.new(5) { SecureRandom.uuid }

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector.data[:consumption_lags] << messages.metadata.consumption_lag
  end
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  elements.each do |data|
    sleep(0.1)
    produce(DataCollector.topic, data)
  end

  DataCollector.data[:consumption_lags].size >= 20
end

assert_equal true, DataCollector.data[:consumption_lags].max < 500
