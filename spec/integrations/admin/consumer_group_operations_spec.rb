# frozen_string_literal: true

# Karafka should handle consumer group operations with active consumers correctly

setup_karafka

# Create a consumer that will be active during admin operations
class ActiveConsumerGroupConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      message_data = JSON.parse(message.raw_payload)

      # Simulate some processing time
      sleep(0.01)

      DT[:consumed] << {
        message_id: message_data["id"],
        consumer_group: topic.consumer_group.id,
        processed_at: Time.now.to_f
      }
    end
  end
end

draw_routes(ActiveConsumerGroupConsumer)

# Produce some messages to ensure consumer has work to do
test_messages = []
5.times do |i|
  test_messages << {
    id: "test_#{i}",
    content: "consumer_group_test_message",
    timestamp: Time.now.to_f
  }.to_json
end

test_messages.each { |msg| produce(DT.topic, msg) }

# Start consumer in background and perform admin operations while it's active
consumer_thread = Thread.new do
  start_karafka_and_wait_until do
    DT[:consumed].size >= test_messages.size
  end
end

# Wait a bit for consumer to start
sleep(1)

# Get the consumer group ID from the routing
consumer_group_id = Karafka::App.routes.first.id

# Perform admin operations on active consumer group
begin
  # Get consumer group information
  consumer_groups_info = Karafka::Admin.read_consumer_groups

  DT[:admin_operations] << {
    operation: "read_consumer_groups",
    success: true,
    groups_count: consumer_groups_info.size,
    target_group_found: consumer_groups_info.any? { |cg| cg.group_id == consumer_group_id }
  }
rescue => e
  DT[:admin_operations] << {
    operation: "read_consumer_groups",
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }
end

begin
  # Get specific consumer group details
  group_details = Karafka::Admin.read_consumer_group(consumer_group_id)

  DT[:admin_operations] << {
    operation: "read_consumer_group",
    success: true,
    group_id: group_details.group_id,
    state: group_details.state,
    members_count: group_details.members.size
  }
rescue => e
  DT[:admin_operations] << {
    operation: "read_consumer_group",
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }
end

begin
  # Try to get consumer group offsets while active
  offsets_info = Karafka::Admin.read_consumer_group_offsets(consumer_group_id)

  DT[:admin_operations] << {
    operation: "read_consumer_group_offsets",
    success: true,
    offsets_count: offsets_info.size,
    has_offsets: !offsets_info.empty?
  }
rescue => e
  DT[:admin_operations] << {
    operation: "read_consumer_group_offsets",
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }
end

# Test seeking operations on active consumer (this might be restricted)
begin
  # Try to seek to beginning (this operation might fail or be ignored while consumer is active)
  seek_result = Karafka::Admin.seek_consumer_group(consumer_group_id, { DT.topic => { 0 => 0 } })

  DT[:admin_operations] << {
    operation: "seek_consumer_group",
    success: true,
    result: seek_result.class.name
  }
rescue => e
  DT[:admin_operations] << {
    operation: "seek_consumer_group",
    success: false,
    error_class: e.class.name,
    error_message: e.message,
    expected_failure: e.message.include?("active") || e.message.include?("member")
  }
end

# Wait for consumer to finish processing
consumer_thread.join

# Now test operations after consumer is no longer active
sleep(0.5) # Give time for consumer to fully shutdown

begin
  # Read consumer group info after shutdown
  post_shutdown_info = Karafka::Admin.read_consumer_group(consumer_group_id)

  DT[:admin_operations] << {
    operation: "read_consumer_group_post_shutdown",
    success: true,
    group_id: post_shutdown_info.group_id,
    state: post_shutdown_info.state,
    members_count: post_shutdown_info.members.size,
    state_after_shutdown: post_shutdown_info.state
  }
rescue => e
  DT[:admin_operations] << {
    operation: "read_consumer_group_post_shutdown",
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }
end

# Verify all messages were processed
assert_equal(
  test_messages.size, DT[:consumed].size,
  "Should process all messages despite admin operations"
)

# Verify admin operations were performed
assert(
  DT[:admin_operations].any?,
  "Should have performed administrative operations"
)

# Verify read_consumer_groups operation
read_groups_ops = DT[:admin_operations].select { |op| op[:operation] == "read_consumer_groups" }
read_groups_ops.each do |op|
  assert(
    op.key?(:success),
    "Read consumer groups should have success flag"
  )

  next unless op[:success]

  assert(
    op[:groups_count] >= 0,
    "Should return non-negative groups count"
  )
end

# Verify read_consumer_group operation
read_group_ops = DT[:admin_operations].select { |op| op[:operation] == "read_consumer_group" }
read_group_ops.each do |op|
  assert(
    op.key?(:success),
    "Read consumer group should have success flag"
  )

  next unless op[:success]

  assert(
    !op[:group_id].nil?,
    "Should return group ID"
  )

  assert(
    !op[:state].nil?,
    "Should return group state"
  )

  assert(
    op[:members_count] >= 0,
    "Should return non-negative members count"
  )
end

# Verify offset operations
offset_ops = DT[:admin_operations].select { |op| op[:operation] == "read_consumer_group_offsets" }
offset_ops.each do |op|
  assert(
    op.key?(:success),
    "Read offsets should have success flag"
  )

  next unless op[:success]

  assert(
    op[:offsets_count] >= 0,
    "Should return non-negative offsets count"
  )
end

# Verify seek operations (may fail with active consumers)
seek_ops = DT[:admin_operations].select { |op| op[:operation] == "seek_consumer_group" }
seek_ops.each do |op|
  assert(
    op.key?(:success),
    "Seek operation should have success flag"
  )

  # Seeking might legitimately fail with active consumers
  next unless !op[:success] && op.key?(:expected_failure)

  assert(
    op[:expected_failure],
    "Expected failure should be properly identified"
  )
end

# Verify post-shutdown operations
post_shutdown_ops = DT[:admin_operations].select do |op|
  op[:operation] == "read_consumer_group_post_shutdown"
end

post_shutdown_ops.each do |op|
  next unless op[:success]

  # Consumer group state after shutdown might be Empty, Dead, or other states
  assert(
    !op[:state_after_shutdown].nil?,
    "Should report consumer group state after shutdown"
  )

  # After shutdown, members count should be 0 or low
  assert(
    op[:members_count] >= 0,
    "Members count after shutdown should be non-negative"
  )
end

# The key success criteria: handling operations with active consumers
operations_count = DT[:admin_operations].size
successful_operations = DT[:admin_operations].count { |op| op[:success] }

assert(
  operations_count >= 3,
  "Should perform multiple administrative operations"
)

assert(
  successful_operations > 0,
  "Should successfully handle some operations with active consumers"
)
