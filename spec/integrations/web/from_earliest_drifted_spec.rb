# frozen_string_literal: true

# Karafka should be able to handle a case where the cluster and consumer times drifted
# Some metrics may not be 100% accurate and this should not happen often but may

setup_karafka
setup_web

# This will "fake" drift of five seconds of the cluster, so cluster is in the future
module Karafka
  module Messages
    class Message
      def timestamp
        metadata.timestamp + 5
      end
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumption_lag] = messages.metadata.consumption_lag
    # Sleep enough to force reporting
    sleep(10)
  end
end

draw_routes(Consumer)

elements = DT.uuids(1)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:consumption_lag) && sleep(5)
end

assert_equal 0, DT[:consumption_lag]
