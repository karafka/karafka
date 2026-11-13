# frozen_string_literal: true

# When the previous consumer group has active members, the rename copies its offsets to the new
# consumer group and then raises on the removal of the previous one. Both consumer groups keep
# the offsets.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    mark_as_consumed!(messages.last)

    messages.each { |message| DT[:offsets] << message.offset }
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

NEW_NAME = SecureRandom.uuid

start_karafka_and_wait_until do
  next false unless DT[:offsets].size >= 10

  begin
    Karafka::Admin.rename_consumer_group(DT.group, NEW_NAME, [DT.topic])
  rescue Rdkafka::RdkafkaError => e
    DT[:error] = e
  end

  true
end

assert DT[:error].is_a?(Rdkafka::RdkafkaError)
assert_equal :non_empty_group, DT[:error].code

previous = Karafka::Admin.read_lags_with_offsets({ DT.group => [DT.topic] })

assert_equal 10, previous.fetch(DT.group).fetch(DT.topic).fetch(0).fetch(:offset)

migrated = Karafka::Admin.read_lags_with_offsets({ NEW_NAME => [DT.topic] })

assert_equal 10, migrated.fetch(NEW_NAME).fetch(DT.topic).fetch(0).fetch(:offset)
