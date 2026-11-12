# frozen_string_literal: true

# When Admin::ConsumerGroups runs on an external consumer client, consumer group offsets are
# still read and changed via the admin API for the queried consumer group. The external consumer
# group.id is not used, so a foreign consumer group gets its own data and the external consumer
# state is not affected in any way (no join, no assignment, no close).

setup_karafka

TOPIC1 = DT.topics[0]
TOPIC2 = DT.topics[1]

OWN_CG = DT.groups[2]
FOREIGN_CG = DT.groups[3]

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

external = Rdkafka::Config.new(
  "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "127.0.0.1:9092"),
  "group.id": OWN_CG
).consumer

external_admin = Karafka::Admin::ConsumerGroups.new(external_client: external)

assert_equal(
  { OWN_CG => { TOPIC1 => OWN_T1 } },
  external_admin.read_lags_with_offsets({ OWN_CG => [TOPIC1] })
)

assert_equal(
  { FOREIGN_CG => { TOPIC1 => FOREIGN_T1, TOPIC2 => FOREIGN_T2 } },
  external_admin.read_lags_with_offsets({ FOREIGN_CG => [TOPIC1, TOPIC2] })
)

# Seeking a foreign consumer group changes that consumer group only
external_admin.seek(FOREIGN_CG, { TOPIC1 => { 0 => 9 } })

assert_equal(
  { OWN_CG => { TOPIC1 => OWN_T1 }, FOREIGN_CG => { TOPIC1 => { 0 => { offset: 9, lag: 1 } } } },
  Karafka::Admin.read_lags_with_offsets({ OWN_CG => [TOPIC1], FOREIGN_CG => [TOPIC1] })
)

assert_equal({}, external.assignment.to_h)
assert_equal({}, external.subscription.to_h)
assert !external.closed?

external.close
