# frozen_string_literal: true

# Karafka should crash when new and old rebalance protocol settings are mixed even if independently
# they are correct.
#
# Note that those errors only happen upon subscription, not during configuration.

setup_karafka(allow_errors: true) do |config|
  config.kafka[:'partition.assignment.strategy'] = 'cooperative-sticky'
  config.kafka[:'group.remote.assignor'] = 'uniform'
  config.kafka[:'group.protocol'] = 'consumer'
end

class Consumer < Karafka::BaseConsumer
  def consume; end
end

Karafka.monitor.subscribe('error.occurred') do |event|
  exit!(1) if event[:error].is_a?(Rdkafka::Config::ClientCreationError)
end

draw_routes(Consumer)

start_karafka_and_wait_until do
  false
end
