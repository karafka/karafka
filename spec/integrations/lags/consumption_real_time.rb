# frozen_string_literal: true

# Karafka should correctly report consumption_lag when we consume messages fast and it should never
# be bigger than couple hundred ms with the defaults for integration specs

setup_karafka do |config|
  config.max_wait_time = 100
end

elements = Array.new(5) { SecureRandom.uuid }

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumption_lags] << messages.metadata.consumption_lag
  end
end

draw_routes(Consumer)

produce(DT.topic, elements.first)

start_karafka_and_wait_until do
  elements.each do |data|
    sleep(0.1)
    produce(DT.topic, data)
  end

  DT[:consumption_lags].size >= 20
end

# We reject first few lags as they often are bigger due to warm-up and partitions assignments
assert DT[:consumption_lags][5...].max < 500
