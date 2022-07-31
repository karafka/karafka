# frozen_string_literal: true

# Karafka should trigger a revoked action when a partition is being taken from us
# Initially we should own all the partitions and then after they are taken away, we should get
# back to two (as the last one will be owned by the second consumer).

TOPIC = 'integrations_03_03'

setup_karafka do |config|
  config.license.token = pro_license_token
end

DataCollector[:revoked] = Concurrent::Array.new
DataCollector[:pre] = Set.new
DataCollector[:post] = Set.new

class Consumer < Karafka::Pro::BaseConsumer
  def consume
    # Pre rebalance
    if DataCollector[:revoked].empty?
      DataCollector[:pre] << messages.metadata.partition
    # Post rebalance
    else
      DataCollector[:post] << messages.metadata.partition
    end
  end

  # Collect info on all the partitions we have lost
  def revoked
    DataCollector[:revoked] << { messages.metadata.partition => Time.now }
  end
end

draw_routes do
  consumer_group TOPIC do
    topic TOPIC do
      consumer Consumer
      manual_offset_management true
    end
  end
end

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(TOPIC, data, partition: rand(0..2)) }

consumer = setup_rdkafka_consumer

other =  Thread.new do
  sleep(10)

  consumer.subscribe(TOPIC)
  # 1 message is enough
  consumer.each do
    next if DataCollector[:end].empty?

    break
  end

  consumer.close
end

start_karafka_and_wait_until do
  if DataCollector[:post].empty?
    false
  else
    sleep 2
    true
  end
end

DataCollector[:end] << true

# Rebalance should revoke all 3 partitions
assert_equal 3, DataCollector[:revoked].size

# There should be no extra partitions or anything like that that was revoked
assert (DataCollector[:revoked].flat_map(&:keys) - [0, 1, 2]).empty?

# Before revocation, we should have had all the partitions in our first process
assert_equal [0, 1, 2], DataCollector[:pre].to_a.sort

re_assigned = DataCollector[:post].to_a.sort
# After rebalance we should not get all partitions back as now there are two consumers
assert_not_equal [0, 1, 2], re_assigned
# It may get either one or two partitions back
assert re_assigned.size == 1 || re_assigned.size == 2

other.join
