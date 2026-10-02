# frozen_string_literal: true

# Karafka::Admin.list_consumer_groups should list the consumer groups that exist in the cluster
# together with their cooked (Symbol) state, and must not include groups that never existed.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[0] << message.offset }
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[0].size >= 10
end

# The cooked states we normalize the librdkafka enum into
ALLOWED_STATES = %i[
  unknown
  preparing_rebalance
  completing_rebalance
  stable
  dead
  empty
].freeze

groups = Karafka::Admin.list_consumer_groups

# Positive control: our group consumed, so it must be present
our = groups.find { |group| group[:group_id] == DT.group }

assert_not_equal nil, our
assert_equal DT.group, our[:group_id]

# State must be one of the cooked symbols, never the raw librdkafka integer
assert ALLOWED_STATES.include?(our[:state]), our[:state]

# After a clean shutdown the group has committed offsets but no live members, so it is empty
assert_equal :empty, our[:state]

# A group that was never created must not appear in the listing
missing = groups.find { |group| group[:group_id] == "#{DT.group}-does-not-exist" }

assert_equal nil, missing
