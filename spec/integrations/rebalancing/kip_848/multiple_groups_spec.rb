# frozen_string_literal: true

# Test multiple consumer groups using the new KIP-848 consumer group protocol
# This ensures different consumer groups can consume the same topic independently

setup_karafka(consumer_group_protocol: true)

class ConsumerGroup1 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:group1] << message.raw_payload
    end
  end
end

class ConsumerGroup2 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:group2] << message.raw_payload
    end
  end
end

class ConsumerGroup3 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:group3] << message.raw_payload
    end
  end
end

# Draw routes with three separate consumer groups, all using KIP-848
draw_routes do
  # First consumer group
  consumer_group "#{DT.consumer_group}-group1" do
    topic DT.topic do
      config(partitions: 3)
      consumer ConsumerGroup1
    end
  end

  # Second consumer group
  consumer_group "#{DT.consumer_group}-group2" do
    topic DT.topic do
      consumer ConsumerGroup2
    end
  end

  # Third consumer group
  consumer_group "#{DT.consumer_group}-group3" do
    topic DT.topic do
      consumer ConsumerGroup3
    end
  end
end

# Produce test messages before starting consumers
elements = DT.uuids(30)
elements.each_with_index do |element, index|
  produce(DT.topic, element, partition: index % 3)
end

start_karafka_and_wait_until do
  # Wait until all three groups have consumed all messages
  DT[:group1].size >= elements.size &&
    DT[:group2].size >= elements.size &&
    DT[:group3].size >= elements.size
end

# Verify all groups consumed all messages independently
assert_equal elements.size, DT[:group1].size, 'Group 1 should consume all messages'
assert_equal elements.size, DT[:group2].size, 'Group 2 should consume all messages'
assert_equal elements.size, DT[:group3].size, 'Group 3 should consume all messages'

# Verify all groups consumed the same messages (but independently)
assert_equal elements.sort, DT[:group1].sort, 'Group 1 should consume all expected messages'
assert_equal elements.sort, DT[:group2].sort, 'Group 2 should consume all expected messages'
assert_equal elements.sort, DT[:group3].sort, 'Group 3 should consume all expected messages'

# Verify that each group processed messages independently
# (they all should have processed all messages since they're separate consumer groups)
assert_equal elements.to_set, DT[:group1].to_set
assert_equal elements.to_set, DT[:group2].to_set
assert_equal elements.to_set, DT[:group3].to_set
