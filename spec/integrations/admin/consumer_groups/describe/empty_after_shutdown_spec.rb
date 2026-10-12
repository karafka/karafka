# frozen_string_literal: true

# Karafka::Admin.describe_consumer_group should report a consumer group as empty with no members
# after a clean shutdown, as it keeps its offsets but has no live members.

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

stopped = Karafka::Admin.describe_consumer_group(DT.group)

assert_equal DT.group, stopped[:group_id]
assert_equal :empty, stopped[:state]
assert_equal [], stopped[:members]
