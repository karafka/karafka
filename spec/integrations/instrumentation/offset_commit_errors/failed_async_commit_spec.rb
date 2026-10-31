# frozen_string_literal: true

# Karafka should publish a failed async offset commit on `error.occurred`. Without the offset
# commit callback, librdkafka only logs it.

setup_karafka(allow_errors: %w[connection.client.commit_offsets.error])

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:client_id)

    DT[:client_id] = client.id

    # The broker rejects a commit for a topic that does not exist
    tpl = Rdkafka::Consumer::TopicPartitionList.new
    tpl.add_topic_and_partitions_with_offsets(DT.topics[1], 0 => 1)
    client.wrapped_kafka.wrapped.commit(tpl, true)
  end
end

draw_routes(Consumer)

errors = []

Karafka::App.monitor.subscribe("error.occurred") do |event|
  errors << event if event[:type] == "connection.client.commit_offsets.error"
end

produce(DT.topic, "1")

start_karafka_and_wait_until do
  !errors.empty?
end

event = errors.first

assert_equal 1, errors.size
assert_equal :unknown_topic_or_part, event[:error].code
assert_equal DT[:client_id], event[:client_id]
assert event[:consumer_group_id].include?(DT.groups.first)
assert_equal false, event[:subscription_group_id].empty?
assert_equal [DT.topics[1]], event[:tpl].to_h.keys
