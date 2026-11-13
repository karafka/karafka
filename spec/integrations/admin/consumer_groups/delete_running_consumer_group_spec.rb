# frozen_string_literal: true

# Deleting a consumer group that has active members should raise and leave its committed offsets
# unchanged, as Kafka deletes only empty consumer groups

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:offsets] << message.offset }

    mark_as_consumed!(messages.last)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  next false unless DT[:offsets].size >= 10

  begin
    Karafka::Admin.delete_consumer_group(DT.group)
  rescue Rdkafka::RdkafkaError => e
    DT[:error] = e
  end

  true
end

assert DT[:error].is_a?(Rdkafka::RdkafkaError)
assert_equal :non_empty_group, DT[:error].code

offsets = Karafka::Admin.read_lags_with_offsets({ DT.group => [DT.topic] })

assert_equal 10, offsets.fetch(DT.group).fetch(DT.topic).fetch(0).fetch(:offset)

# Once the consumer group is stopped, it can be deleted
Karafka::Admin.delete_consumer_group(DT.group)

offsets = Karafka::Admin.read_lags_with_offsets({ DT.group => [DT.topic] })

assert_equal(-1, offsets.fetch(DT.group).fetch(DT.topic).fetch(0).fetch(:offset))
