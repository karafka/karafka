# frozen_string_literal: true

# Karafka::Admin.read_committed_offsets should read all committed offsets of several consumer
# groups without being given their topics: only committed partitions, also of topics outside of
# the routing, in the requested order, and an empty hash for a consumer group without commits.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[0] << message.offset }
  end
end

draw_topics do
  topic DT.topics[0] do
    partitions 2
  end
end

draw_routes do
  consumer_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
    end
  end
end

Karafka::Admin.create_topic(DT.topics[1], 3, 1)

produce_many(DT.topics[0], DT.uuids(10), partition: 0)
produce_many(DT.topics[1], DT.uuids(5), partition: 2)

start_karafka_and_wait_until do
  DT[0].size >= 10
end

other_group = "#{DT.group}-other"
never_group = "#{DT.group}-never"

# A topic that is not in the routing of this consumer group
Karafka::Admin.seek_consumer_group(DT.group, { DT.topics[1] => { 2 => 4 } })
Karafka::Admin.seek_consumer_group(other_group, { DT.topics[1] => { 2 => 1 } })

results = Karafka::Admin.read_committed_offsets(other_group, never_group, DT.group)

assert_equal [other_group, never_group, DT.group], results.keys
assert_equal({ DT.topics[1] => { 2 => 1 } }, results[other_group])
assert_equal({}, results[never_group])
assert_equal(
  { DT.topics[0] => { 0 => 10 }, DT.topics[1] => { 2 => 4 } },
  results[DT.group]
)
