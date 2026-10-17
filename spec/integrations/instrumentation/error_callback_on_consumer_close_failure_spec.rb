# frozen_string_literal: true

# When closing the librdkafka consumer fails, Karafka should publish it via "error.occurred" for
# the subscription group of that consumer instead of dropping it.
#
# We close the native consumer from within `#consume`. The next poll then fails with `destroy`,
# so the listener fetch loop resets the client and `Client#close` fails, as librdkafka reports
# that the consumer is already closed.

setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:native_closed)

    DT[:subscription_group_id] = topic.subscription_group.id

    client
      .instance_variable_get(:@kafka)
      .instance_variable_get(:@native_kafka)
      .synchronize { |inner| Rdkafka::Bindings.rd_kafka_consumer_close(inner) }

    DT[:native_closed] = true
  end
end

draw_routes(Consumer)

produce(DT.topic, "1")

Karafka::App.monitor.subscribe("error.occurred") do |event|
  next unless event[:type] == "librdkafka.error"
  next unless event[:error].is_a?(Rdkafka::RdkafkaError)
  next unless event[:error].broker_message == "Consumer close failed"

  DT[:close_errors] << event
end

start_karafka_and_wait_until do
  DT.key?(:native_closed)
end

assert_equal 1, DT[:close_errors].size

event = DT[:close_errors].first

assert_equal DT[:subscription_group_id], event[:subscription_group_id]
assert event[:consumer_group_id].include?(DT.groups.first)
