# frozen_string_literal: true

# When processing data fast, the processing lag should not be big and things should be processed
# almost real time

setup_karafka do |config|
  config.max_messages = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:processing_lags] << messages.metadata.processing_lag
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:processing_lags].size >= 20
end

# We give it a bit of time, because on heavily loaded systems running multiple things it can lag
assert DT[:processing_lags].max <= 100
