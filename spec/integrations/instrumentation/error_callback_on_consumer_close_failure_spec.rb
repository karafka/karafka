# frozen_string_literal: true

# When closing the librdkafka consumer fails, Karafka should publish it via "error.occurred" for
# the subscription group of that consumer instead of dropping it.
#
# Once a message is consumed, `rd_kafka_consumer_close` runs twice per call. On shutdown the
# second close fails, as librdkafka reports that the consumer is already closed.

setup_karafka(allow_errors: true)

module DoubleConsumerClose
  def rd_kafka_consumer_close(inner)
    return super unless DT.key?(:consumed)

    super
    super
  end
end

Rdkafka::Bindings.singleton_class.prepend(DoubleConsumerClose)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:subscription_group_id] = topic.subscription_group.id
    DT[:consumed] = true
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
  DT.key?(:consumed)
end

assert_equal 1, DT[:close_errors].size

event = DT[:close_errors].first

assert_equal DT[:subscription_group_id], event[:subscription_group_id]
assert event[:consumer_group_id].include?(DT.groups.first)
