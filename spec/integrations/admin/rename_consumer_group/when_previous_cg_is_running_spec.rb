# frozen_string_literal: true

# When the previous consumer group has active members, the rename should raise
# `Karafka::Errors::ConsumerGroupNotEmptyError` before it copies any offsets. The previous consumer
# group keeps its offsets and the new consumer group gets none.

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
  rescue Karafka::Errors::ConsumerGroupNotEmptyError => e
    DT[:error] = e
  end

  true
end

assert DT[:error].is_a?(Karafka::Errors::ConsumerGroupNotEmptyError)
assert_equal DT.group, DT[:error].message

previous = Karafka::Admin.read_lags_with_offsets({ DT.group => [DT.topic] })

assert_equal 10, previous.fetch(DT.group).fetch(DT.topic).fetch(0).fetch(:offset)

migrated = Karafka::Admin.read_lags_with_offsets({ NEW_NAME => [DT.topic] })

assert_equal(-1, migrated.fetch(NEW_NAME).fetch(DT.topic).fetch(0).fetch(:offset))
