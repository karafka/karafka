# frozen_string_literal: true

# When read_lags_with_offsets runs on a borrowed client, committed offsets are always fetched
# within the borrowed consumer group.id identity. Group names from the query are never sent to
# Kafka - they are only used as result keys. Querying a foreign group is silently wrong in two
# flavors: topics the borrowed group consumed come back with the borrowed group offsets and lags
# mislabeled under the foreign group name, and topics it never consumed backfill to -1/-1 even
# when the foreign group has real committed offsets there. No error is raised and the borrowed
# consumer state is not affected in any way (no join, no assignment, no close). This is why
# borrowed clients should be queried only about their own group.

setup_karafka

TOPIC1 = DT.topics[0]
TOPIC2 = DT.topics[1]

OWN_CG = DT.topics[2]
FOREIGN_CG = DT.topics[3]

draw_topics do
  topic TOPIC1 do
    partitions 1
  end

  topic TOPIC2 do
    partitions 1
  end
end

produce_many(TOPIC1, DT.uuids(10))
produce_many(TOPIC2, DT.uuids(10))

# Own group consumed TOPIC1 only, foreign group consumed both topics with different offsets
Karafka::Admin.seek_consumer_group(OWN_CG, { TOPIC1 => { 0 => 3 } })
Karafka::Admin.seek_consumer_group(FOREIGN_CG, { TOPIC1 => { 0 => 7 }, TOPIC2 => { 0 => 5 } })

OWN_T1 = { 0 => { offset: 3, lag: 7 } }.freeze
FOREIGN_T1 = { 0 => { offset: 7, lag: 3 } }.freeze
FOREIGN_T2 = { 0 => { offset: 5, lag: 5 } }.freeze
NA = { 0 => { offset: -1, lag: -1 } }.freeze

# Reference values via dedicated per-group consumers - this is the correct data
assert_equal(
  {
    OWN_CG => { TOPIC1 => OWN_T1 },
    FOREIGN_CG => { TOPIC1 => FOREIGN_T1, TOPIC2 => FOREIGN_T2 }
  },
  Karafka::Admin.read_lags_with_offsets(
    { OWN_CG => [TOPIC1], FOREIGN_CG => [TOPIC1, TOPIC2] }
  )
)

borrowed = Rdkafka::Config.new(
  "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:9092"),
  "group.id": OWN_CG
).consumer

borrowed_admin = Karafka::Admin::ConsumerGroups.new(borrowed_client: borrowed)

# Case 1 - borrowed client queried about its own group gives correct data
assert_equal(
  { OWN_CG => { TOPIC1 => OWN_T1 } },
  borrowed_admin.read_lags_with_offsets({ OWN_CG => [TOPIC1] })
)

# Case 2 - foreign group query on a topic the borrowed group consumed silently returns the
# borrowed group offsets and lags mislabeled under the foreign group name
misattributed = borrowed_admin.read_lags_with_offsets({ FOREIGN_CG => [TOPIC1] })

assert_equal({ FOREIGN_CG => { TOPIC1 => OWN_T1 } }, misattributed)
assert_not_equal(FOREIGN_T1, misattributed.fetch(FOREIGN_CG).fetch(TOPIC1))

# Case 3 - foreign group query on a topic the borrowed group never consumed backfills to -1/-1
# despite the foreign group having real committed offsets there, indistinguishable from a group
# that never consumed
assert_equal(
  { FOREIGN_CG => { TOPIC2 => NA } },
  borrowed_admin.read_lags_with_offsets({ FOREIGN_CG => [TOPIC2] })
)

# All of the above is read-only within the borrowed identity - the borrowed consumer was not
# joined to the group, assigned, subscribed or closed
assert_equal({}, borrowed.assignment.to_h)
assert_equal({}, borrowed.subscription.to_h)
assert !borrowed.closed?

borrowed.close
