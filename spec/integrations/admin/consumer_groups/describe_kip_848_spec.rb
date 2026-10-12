# frozen_string_literal: true

# Karafka::Admin.describe_consumer_group should describe KIP-848 (consumer protocol) groups: stable
# with the live member holding all the partitions while running and empty after shutdown.

setup_karafka(consumer_group_protocol: true)

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

assert_equal :stable, live[:state]
assert_equal 1, live[:members].size
assert_equal({ DT.topic => [0, 1] }, live[:members].first[:assignment])

stopped = Karafka::Admin.describe_consumer_group(DT.group)

assert_equal :empty, stopped[:state]
assert_equal [], stopped[:members]
