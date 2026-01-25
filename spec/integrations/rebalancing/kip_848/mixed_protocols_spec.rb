# frozen_string_literal: true

# Test that both old (eager/cooperative) and new (KIP-848) rebalance protocols
# can work simultaneously in different consumer groups within Karafka

# We'll set up multiple Karafka apps with different configurations
# to simulate different consumer groups with different protocols

# Consumer class for KIP-848 group
class Kip848Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:kip848_messages] << message.raw_payload
    end
  end
end

# Consumer class for cooperative-sticky group
class CooperativeConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:cooperative_messages] << message.raw_payload
    end
  end
end

# Consumer class for range/roundrobin group
class RangeConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:range_messages] << message.raw_payload
    end
  end
end

# Setup main Karafka app with base configuration
# Keep default settings, we'll customize per consumer group
setup_karafka

# Draw routes with different consumer groups using different protocols
draw_routes do
  # Consumer group using KIP-848
  consumer_group "#{DT.consumer_group}-kip848" do
    topic DT.topic do
      config(partitions: 3)
      consumer Kip848Consumer
      # Configure this group to use KIP-848
      kafka(
        Karafka::App.config.kafka
          .merge("group.protocol": "consumer")
          .except(:"partition.assignment.strategy", :"heartbeat.interval.ms")
      )
    end
  end

  # Consumer group using cooperative-sticky (old protocol)
  consumer_group "#{DT.consumer_group}-cooperative" do
    topic DT.topic do
      consumer CooperativeConsumer
      # Use old protocol with cooperative-sticky
      kafka(
        Karafka::App.config.kafka.merge(
          "partition.assignment.strategy": "cooperative-sticky"
        )
      )
    end
  end

  # Consumer group using range,roundrobin (old protocol)
  consumer_group "#{DT.consumer_group}-range" do
    topic DT.topic do
      consumer RangeConsumer
      # Use old protocol with range,roundrobin
      kafka(
        Karafka::App.config.kafka.merge(
          "partition.assignment.strategy": "range,roundrobin"
        )
      )
    end
  end
end

# Produce test messages
messages = DT.uuids(30)
messages.each_with_index do |msg, i|
  produce(DT.topic, msg, partition: i % 3)
end

start_karafka_and_wait_until do
  # Wait until all three consumer groups have consumed messages
  DT[:kip848_messages].size >= 20 &&
    DT[:cooperative_messages].size >= 20 &&
    DT[:range_messages].size >= 20
end

assert DT[:kip848_messages].size >= 20
assert DT[:cooperative_messages].size >= 20
assert DT[:range_messages].size >= 20

# All groups should see the same messages (though not necessarily all due to timing)
all_produced = messages.to_set

# Check that consumed messages are from the produced set
assert((DT[:kip848_messages].to_set - all_produced).empty?)
assert((DT[:cooperative_messages].to_set - all_produced).empty?)
assert((DT[:range_messages].to_set - all_produced).empty?)

# Verify that different protocols can coexist
# Each group should have consumed messages independently
assert DT[:kip848_messages].any?, "KIP-848 group should have consumed messages"
assert DT[:cooperative_messages].any?, "Cooperative group should have consumed messages"
assert DT[:range_messages].any?, "Range group should have consumed messages"
