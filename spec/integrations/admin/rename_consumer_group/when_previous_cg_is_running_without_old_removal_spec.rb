# frozen_string_literal: true

# When the previous consumer group has active members and we indicate that it should stay, the
# rename should copy its offsets to the new consumer group without raising, as Kafka accepts
# offset changes of the new consumer group that has no members

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

  DT[:result] = Karafka::Admin.rename_consumer_group(
    DT.group,
    NEW_NAME,
    [DT.topic],
    delete_previous: false
  )

  true
end

assert DT[:result]

previous = Karafka::Admin.read_lags_with_offsets({ DT.group => [DT.topic] })

assert_equal 10, previous.fetch(DT.group).fetch(DT.topic).fetch(0).fetch(:offset)

migrated = Karafka::Admin.read_lags_with_offsets({ NEW_NAME => [DT.topic] })

assert_equal 10, migrated.fetch(NEW_NAME).fetch(DT.topic).fetch(0).fetch(:offset)
