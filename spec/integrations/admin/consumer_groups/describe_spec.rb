# frozen_string_literal: true

# Karafka::Admin.describe_consumer_group should report a running group as stable with its live
# member holding all the partitions, the same group as empty with no members after shutdown, and
# a group that never existed as dead with no members.

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[0] << message.offset }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 2)
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  next false unless DT[0].size >= 10

  DT[:live] = Karafka::Admin.describe_consumer_group(DT.group)

  true
end

live = DT[:live]

assert_equal DT.group, live[:group_id]
assert_equal :stable, live[:state]
assert_equal 1, live[:members].size

member = live[:members].first

assert member[:member_id].is_a?(String), member
assert member[:host].is_a?(String), member
assert_equal({ DT.topic => [0, 1] }, member[:assignment])
assert live[:coordinator][:id].is_a?(Integer), live[:coordinator]

# After a clean shutdown the group keeps its offsets but has no live members
stopped = Karafka::Admin.describe_consumer_group(DT.group)

assert_equal :empty, stopped[:state]
assert_equal [], stopped[:members]

# A group that was never created is reported as dead, not as an error
missing = Karafka::Admin.describe_consumer_group("#{DT.group}-does-not-exist")

assert_equal :dead, missing[:state]
assert_equal [], missing[:members]
