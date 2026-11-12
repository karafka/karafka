# frozen_string_literal: true

# Deleting committed offsets of a running consumer group should work for a topic it no longer
# consumes, and raise a clear error for a topic it is subscribed to, leaving those offsets in place.
# In a mixed request, offsets of the not subscribed topic are deleted before the error is raised.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:offsets] << message.offset }

    mark_as_consumed!(messages.last)
  end
end

draw_routes(Consumer)

removed_topic = DT.topics[1]

Karafka::Admin.create_partitions(DT.topic, 2)
Karafka::Admin.create_topic(removed_topic, 2, 1)
Karafka::Admin.seek_consumer_group(DT.group, { removed_topic => { 0 => 5, 1 => 7 } })

produce_many(DT.topic, DT.uuids(10), partition: 0)

start_karafka_and_wait_until do
  next false unless DT[:offsets].size >= 10

  Karafka::Admin.delete_consumer_group_offsets(DT.group, { removed_topic => [0] })

  begin
    Karafka::Admin.delete_consumer_group_offsets(DT.group, [DT.topic, removed_topic])
  rescue Karafka::Errors::ConsumerGroupSubscribedToTopicError => e
    DT[:error] = e
  end

  true
end

assert DT[:error].is_a?(Karafka::Errors::ConsumerGroupSubscribedToTopicError)
assert_equal "#{DT.group}: #{DT.topic}#0, #{DT.topic}#1", DT[:error].message

offsets = Karafka::Admin.read_lags_with_offsets({ DT.group => [DT.topic, removed_topic] })

assert_equal 10, offsets.fetch(DT.group).fetch(DT.topic).fetch(0).fetch(:offset)
assert_equal(
  { 0 => -1, 1 => -1 },
  offsets.fetch(DT.group).fetch(removed_topic).transform_values { |details| details[:offset] }
)

# Once the consumer group is stopped, offsets of its former topic can be deleted too
Karafka::Admin.delete_consumer_group_offsets(DT.group, { DT.topic => [0] })

offsets = Karafka::Admin.read_lags_with_offsets({ DT.group => [DT.topic] })

assert_equal(-1, offsets.fetch(DT.group).fetch(DT.topic).fetch(0).fetch(:offset))
