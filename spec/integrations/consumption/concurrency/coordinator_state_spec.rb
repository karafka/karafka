# frozen_string_literal: true

# Karafka should handle coordinator state during rapid message flow safely

setup_karafka

class CoordinatorStateConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      thread_id = Thread.current.object_id
      message_data = JSON.parse(message.raw_payload)

      # Access coordinator state during processing
      coordinator_info = {
        thread_id: thread_id,
        message_id: message_data['id'],
        coordinator_class: coordinator.class.name,
        coordinator_object_id: coordinator.object_id,
        has_coordinator: !coordinator.nil?,
        processing_state: capture_coordinator_state
      }

      # Simulate varying processing times to test coordinator state consistency
      processing_time = message_data['processing_time'] || 0.001
      sleep(processing_time)

      # Verify coordinator state remains consistent during processing
      post_processing_state = capture_coordinator_state

      # Check for state consistency
      if post_processing_state[:has_messages] != coordinator_info[:processing_state][:has_messages]
        DT[:errors] << "Coordinator state inconsistency detected for message #{message_data['id']}"
      end

      # Store results for verification
      DT[:consumed] << coordinator_info.merge(
        post_processing_state: post_processing_state,
        messages_batch_size: messages.size,
        message_offset: message.metadata.offset
      )
    end
  end

  private

  def capture_coordinator_state
    {
      has_messages: !messages.empty?,
      messages_count: messages.size,
      coordinator_exists: !coordinator.nil?,
      processing_thread: Thread.current.object_id
    }
  end
end

draw_routes(CoordinatorStateConsumer)

# Create messages with different processing characteristics
coordinator_messages = []
25.times do |i|
  coordinator_messages << {
    id: i + 1,
    processing_time: (i % 4) * 0.0005, # Varying processing times: 0, 0.5ms, 1ms, 1.5ms
    batch_position: i
  }.to_json
end

# Produce all messages rapidly to test coordinator state under load
coordinator_messages.each { |msg| produce(DT.topic, msg) }

start_karafka_and_wait_until do
  DT[:consumed].size >= coordinator_messages.size
end

# Verify all messages were processed
assert_equal(
  coordinator_messages.size, DT[:consumed].size,
  'Should process all messages despite coordinator state access'
)

# Verify no coordinator state errors occurred
assert DT[:errors].empty?, "Coordinator state errors detected: #{DT[:errors].join(', ')}"

# Verify coordinator consistency across all messages
coordinators_used = DT[:consumed].map { |entry| entry[:coordinator_object_id] }.uniq
assert_equal(
  1, coordinators_used.size,
  'Should use single coordinator instance across all messages in batch'
)

coordinator_classes = DT[:consumed].map { |entry| entry[:coordinator_class] }.uniq
assert_equal(
  1, coordinator_classes.size,
  'Should use consistent coordinator class'
)

# Verify all messages had access to coordinator
DT[:consumed].each do |entry|
  assert entry[:has_coordinator],
         'All messages should have access to coordinator'

  assert entry[:processing_state][:coordinator_exists],
         'Coordinator should exist during processing'

  assert entry[:processing_state][:has_messages],
         'Should have access to messages during processing'

  assert entry[:processing_state][:messages_count] > 0,
         'Should have non-zero message count'
end

# Verify message batch consistency
batch_sizes = DT[:consumed].map { |entry| entry[:messages_batch_size] }.uniq
assert_equal(
  1, batch_sizes.size,
  'All messages should see the same batch size'
)

expected_batch_size = coordinator_messages.size
assert_equal(
  expected_batch_size, batch_sizes.first,
  'Batch size should match expected message count'
)

# Verify thread consistency within coordinator context
processing_threads = DT[:consumed].map do |entry|
  entry[:processing_state][:processing_thread]
end.uniq
assert_equal(
  1, processing_threads.size,
  'All messages in batch should be processed by same thread'
)

# Verify offset ordering consistency
offsets = DT[:consumed].map { |entry| entry[:message_offset] }.sort
expected_offsets = (0...coordinator_messages.size).to_a
assert_equal(
  expected_offsets, offsets,
  'Message offsets should be consecutive'
)

# Verify state consistency between pre and post processing
DT[:consumed].each do |entry|
  pre_state = entry[:processing_state]
  post_state = entry[:post_processing_state]

  assert_equal(
    pre_state[:has_messages], post_state[:has_messages],
    'Message availability should be consistent during processing'
  )

  assert_equal(
    pre_state[:messages_count], post_state[:messages_count],
    'Message count should be consistent during processing'
  )

  assert_equal(
    pre_state[:coordinator_exists], post_state[:coordinator_exists],
    'Coordinator existence should be consistent during processing'
  )
end

# The key success criteria: coordinator state handled correctly during rapid message flow

assert_equal(
  coordinator_messages.size, DT[:consumed].size,
  'Should handle coordinator state access during rapid message flow without corruption'
)
