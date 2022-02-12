# frozen_string_literal: true

# Karafka should correctly report consumption_lag when there is a delay in between publishing
# messages and their consumption

setup_karafka

elements = Array.new(5) { SecureRandom.uuid }

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector.data[:consumption_lag] = messages.metadata.consumption_lag
  end
end

draw_routes(Consumer)

elements.each do |data|
  # We sleep here to make sure, that the lag is not computed on any of the messages except last
  # from a single batch
  sleep(0.5)
  produce(DataCollector.topic, data)
end

# Give it some time so we have bigger consumption lag
sleep(2)

start_karafka_and_wait_until do
  DataCollector.data.key?(:consumption_lag)
end

lag = DataCollector.data[:consumption_lag]

assert_equal true, (2_000...4_000).cover?(lag)
