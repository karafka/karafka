# frozen_string_literal: true

# Skip until all explicit modules gems are released due to loading issues
exit if RUBY_VERSION.include?('2.7.8')

# Karafka should be able to handle a case where the cluster and consumer times drifted
# Some metrics may not be 100% accurate and this should not happen often but may

setup_karafka
setup_web

# This will "fake" drift of five seconds of the cluster, so cluster is in the future
module Karafka
  module Messages
    class Message
      def timestamp
        metadata.timestamp + 60
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

assert DT[:consumption_lag] >= 0
