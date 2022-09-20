# frozen_string_literal: true

# Karafka should trigger a revoked action when a partition is being taken from us
# Initially we should own all the partitions and then after they are taken away, we should get
# back to two (as the last one will be owned by the second consumer).

setup_karafka

create_topic(partitions: 3)

DT[:revoked] = Concurrent::Array.new
DT[:pre] = Set.new
DT[:post] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    # Pre rebalance
    if DT[:revoked].empty?
      DT[:pre] << messages.metadata.partition
    # Post rebalance
    else
      DT[:post] << messages.metadata.partition
    end
  end

  # Collect info on all the partitions we have lost
  def revoked
    DT[:revoked] << { messages.metadata.partition => Time.now }
  end
end

draw_routes do
  consumer_group DT.topic do
    topic DT.topic do
      consumer Consumer
      manual_offset_management true
    end
  end
end

elements = DT.uuids(100)
elements.each { |data| produce(DT.topic, data, partition: rand(0..2)) }

consumer = setup_rdkafka_consumer

other =  Thread.new do
  sleep(10)

  consumer.subscribe(DT.topic)
  # 1 message is enough
  consumer.each do
    next if DT[:end].empty?

    break
  end

  sleep(2)

  consumer.close
end

start_karafka_and_wait_until do
  if DT[:post].empty?
    false
  else
    sleep 2
    true
  end
end

DT[:end] << true

# Rebalance should revoke all 3 partitions
assert_equal 3, DT[:revoked].size

# There should be no extra partitions or anything like that that was revoked
assert (DT[:revoked].flat_map(&:keys) - [0, 1, 2]).empty?

# Before revocation, we should have had all the partitions in our first process
assert_equal [0, 1, 2], DT[:pre].to_a.sort

re_assigned = DT[:post].to_a.sort
# After rebalance we should not get all partitions back as now there are two consumers
assert_not_equal [0, 1, 2], re_assigned
# It may get either one or two partitions back
assert re_assigned.size == 1 || re_assigned.size == 2

other.join
