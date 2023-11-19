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
    DT[:processing_lags] << messages.metadata.processing_lag
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:processing_lags].size >= 20
end

def median(array)
  return nil if array.empty?

  sorted = array.sort
  len = sorted.length
  (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
end

assert_equal 0, median(DT[:processing_lags])

# 100ms for slow ci
assert DT[:processing_lags].max <= 100
