# frozen_string_literal: true

# Karafka should be able to stop even before the initial rebalance and should not crash
# @see https://github.com/confluentinc/librdkafka/issues/4312

# We can get a forceful shutdown here when we decide to close before actually polling and
# triggering a rebalance
#
# We ignore it because here we check if the whole process does not crash due to librdkafka issue
setup_karafka(allow_errors: true) do |config|
  config.kafka[:'partition.assignment.strategy'] = 'cooperative-sticky'
  # Increased to compensate for potential wait on long wait
  config.shutdown_timeout = 120_000
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
