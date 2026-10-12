# frozen_string_literal: true

# Karafka::Admin.describe_consumer_group should report a running consumer group as stable, with
# its live member holding all the partitions and with the coordinator broker.

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
assert live[:coordinator][:id].is_a?(Integer), live[:coordinator]

member = live[:members].first

assert member[:member_id].is_a?(String), member
assert member[:host].is_a?(String), member
assert_equal({ DT.topic => [0, 1] }, member[:assignment])
