# frozen_string_literal: true

# Karafka should be able to handle a case where the cluster and consumer times drifted
# Some metrics may not be 100% accurate and this should not happen often but may

setup_karafka

# This will "fake" drift of five seconds of the cluster, so cluster is in the future
class Karafka::Messages::Message
  def timestamp
    metadata.timestamp + 5
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumption_lag] = messages.metadata.consumption_lag
  end
end

draw_routes(Consumer)

elements = DT.uuids(1)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:consumption_lag)
end

assert_equal 0, DT[:consumption_lag]
