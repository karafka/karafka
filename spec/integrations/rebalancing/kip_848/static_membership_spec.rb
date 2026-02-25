# frozen_string_literal: true

# Test that static group membership works correctly with KIP-848 consumer protocol
# Static membership allows a consumer to maintain its partition assignment across restarts

STATIC_INSTANCE_ID = "static-member-#{SecureRandom.uuid}".freeze

setup_karafka(consumer_group_protocol: true) do |config|
  # Configure static group membership
  config.kafka[:"group.instance.id"] = STATIC_INSTANCE_ID
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.raw_payload
      DT[:partitions] << messages.metadata.partition
    end
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 3)
    consumer Consumer
  end
end

# Produce test messages
messages = DT.uuids(30)
messages.each_with_index do |msg, i|
  produce(DT.topic, msg, partition: i % 3)
end

# Start and consume messages
start_karafka_and_wait_until do
  DT[:consumed].size >= 30
end

# Verify consumption worked
assert_equal 30, DT[:consumed].size
assert_equal 30, DT[:consumed].uniq.size

# Verify all partitions were assigned to this static member
assert_equal [0, 1, 2], DT[:partitions].uniq.sort
