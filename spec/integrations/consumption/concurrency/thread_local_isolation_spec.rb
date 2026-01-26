# frozen_string_literal: true

# Karafka should handle thread-local variable isolation properly

setup_karafka

class ThreadLocalIsolationConsumer < Karafka::BaseConsumer
  # Thread-local storage simulation using thread-specific instance variables
  def consume
    messages.each do |message|
      thread_id = Thread.current.object_id
      message_data = JSON.parse(message.raw_payload)

      # Set thread-local data
      Thread.current[:karafka_test_data] = {
        message_id: message_data["id"],
        processing_start: Time.now.to_f,
        thread_id: thread_id
      }

      # Simulate some processing time
      sleep_time = message_data["sleep_time"] || 0.001
      sleep(sleep_time)

      # Read thread-local data (should be unchanged despite concurrent processing)
      thread_local_data = Thread.current[:karafka_test_data]

      # Verify thread-local data integrity
      unless thread_local_data[:message_id] == message_data["id"]
        DT[:errors] << "Thread-local data corruption detected"
      end

      unless thread_local_data[:thread_id] == thread_id
        DT[:errors] << "Thread-local data corruption detected: thread_id mismatch"
      end

      # Test instance variables per thread
      @instance_var = "message_#{message_data["id"]}_thread_#{thread_id}"

      # Store results for verification
      DT[:consumed] << {
        thread_id: thread_id,
        message_id: message_data["id"],
        instance_var: @instance_var,
        thread_local_message_id: thread_local_data[:message_id],
        thread_local_thread_id: thread_local_data[:thread_id],
        processing_time: Time.now.to_f - thread_local_data[:processing_start]
      }

      # Clean up thread-local storage
      Thread.current[:karafka_test_data] = nil
      @instance_var = nil
    end
  end
end

draw_routes(ThreadLocalIsolationConsumer)

# Create messages with varying processing times to encourage thread interleaving
thread_local_messages = []
20.times do |i|
  thread_local_messages << {
    id: i + 1,
    sleep_time: (i % 3) * 0.001 # 0ms, 1ms, or 2ms sleep
  }.to_json
end

# Produce all messages to encourage concurrent processing
thread_local_messages.each { |msg| produce(DT.topic, msg) }

start_karafka_and_wait_until do
  DT[:consumed].size >= thread_local_messages.size
end

# Verify all messages were processed
assert_equal(
  thread_local_messages.size, DT[:consumed].size,
  "Should process all messages despite thread-local variable usage"
)

# Verify no thread-local data corruption occurred
assert DT[:errors].empty?, "Thread-local data corruption detected: #{DT[:errors].join(", ")}"

# Verify each message was processed with correct thread-local data
DT[:consumed].each do |entry|
  assert_equal(
    entry[:message_id], entry[:thread_local_message_id],
    "Thread-local message ID should match actual message ID"
  )

  assert_equal(
    entry[:thread_id], entry[:thread_local_thread_id],
    "Thread-local thread ID should match actual thread ID"
  )

  expected_instance_var = "message_#{entry[:message_id]}_thread_#{entry[:thread_id]}"
  assert_equal(
    expected_instance_var, entry[:instance_var],
    "Instance variable should contain correct thread-specific data"
  )
end

# Verify proper thread isolation - no cross-thread contamination
thread_groups = DT[:consumed].group_by { |entry| entry[:thread_id] }
thread_groups.each do |thread_id, entries|
  # Within each thread, all data should be consistent with that thread
  entries.each do |entry|
    assert_equal(
      thread_id, entry[:thread_id],
      "Thread ID should be consistent within thread group"
    )

    assert_equal(
      thread_id, entry[:thread_local_thread_id],
      "Thread-local data should be consistent within thread"
    )

    assert entry[:instance_var].include?("thread_#{thread_id}"),
      "Instance variable should contain correct thread ID"
  end
end

# Verify timing consistency - processing times should be reasonable
processing_times = DT[:consumed].map { |entry| entry[:processing_time] }
assert processing_times.all? { |time| time > 0 && time < 0.1 },
  "Processing times should be reasonable (between 0 and 0.1 seconds)"

# Verify thread independence - different threads should have different data
if thread_groups.size > 1
  thread_data_sets = thread_groups.values.map do |entries|
    entries.map { |entry| entry[:instance_var] }
  end

  # No thread should have data from another thread
  thread_data_sets.combination(2).each do |set1, set2|
    intersection = set1 & set2

    assert(
      intersection.empty?,
      "Different threads should not share instance variable data"
    )
  end
end

# The key success criteria: thread-local variables properly isolated

assert_equal(
  thread_local_messages.size, DT[:consumed].size,
  "Should handle thread-local variable isolation without cross-thread contamination"
)
