# frozen_string_literal: true

# Karafka should be able to stop even before the initial rebalance and should not crash
# @see https://github.com/confluentinc/librdkafka/issues/4312

setup_karafka do |config|
  config.kafka[:'partition.assignment.strategy'] = 'cooperative-sticky'
end

class Consumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

start_karafka_and_wait_until do
  true
end
