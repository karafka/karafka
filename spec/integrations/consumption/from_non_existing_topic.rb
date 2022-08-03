# frozen_string_literal: true

# Karafka should raise an exception when trying to work with non-reachable or non-existing topic
# and should retry connecting.

setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes(Consumer)

detected_error = false

Karafka.monitor.subscribe('error.occurred') do |event|
  error = event[:error]

  raise unless error.is_a?(Rdkafka::RdkafkaError)
  raise unless error.code == :unknown_topic_or_part

  detected_error = true
end

start_karafka_and_wait_until { detected_error }
