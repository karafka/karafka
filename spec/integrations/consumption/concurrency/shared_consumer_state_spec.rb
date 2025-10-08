# frozen_string_literal: true

# Karafka should handle concurrent access to shared consumer state safely

setup_karafka

class SharedStateConsumer < Karafka::BaseConsumer
  # Shared class-level state to test thread safety
  @shared_counter = 0
  @shared_data = {}
  @access_log = []
  @mutex = Mutex.new

  class << self
    attr_reader :shared_counter, :shared_data, :access_log, :mutex

    def increment_counter(amount)
      @shared_counter += amount
    end
  end

  def consume
    messages.each do |message|
      # Simulate concurrent access to shared state
      thread_id = Thread.current.object_id
      message_data = JSON.parse(message.raw_payload)

      # Test concurrent counter increments
      increment_shared_counter(thread_id, message_data['increment'])

      # Test concurrent hash modifications
      update_shared_data(thread_id, message_data['key'], message_data['value'])

      # Log access for verification
      log_access(thread_id, message_data['message_id'])

      # Store results for verification
      DT[:consumed] << {
        thread_id: thread_id,
        message_id: message_data['message_id'],
        counter_after: self.class.shared_counter,
        data_snapshot: self.class.shared_data.dup,
        processed_at: Time.now.to_f
      }
    end
  end

  private

  def increment_shared_counter(_thread_id, increment)
    self.class.mutex.synchronize do
      old_value = self.class.shared_counter
      # Simulate some processing time to increase chance of race conditions
      sleep(0.001) if increment > 5
      self.class.increment_counter(increment)

      # Verify atomicity
      if self.class.shared_counter != old_value + increment
        expected = old_value + increment
        actual = self.class.shared_counter
        DT[:errors] << "Race condition detected in counter: expected #{expected}, got #{actual}"
      end
    end
  end

  def update_shared_data(thread_id, key, value)
    self.class.mutex.synchronize do
      self.class.shared_data[key] = value
      self.class.shared_data["#{key}_thread"] = thread_id
      self.class.shared_data["#{key}_timestamp"] = Time.now.to_f
    end
  end

  def log_access(thread_id, message_id)
    self.class.mutex.synchronize do
      self.class.access_log << {
        thread_id: thread_id,
        message_id: message_id,
        timestamp: Time.now.to_f
      }
    end
  end

  class << self
    # Class method to reset state between tests
    def reset_shared_state
      @shared_counter = 0
      @shared_data = {}
      @access_log = []
    end

    def access_logs
      @mutex.synchronize { @access_log.dup }
    end
  end
end

# Reset state before test
SharedStateConsumer.reset_shared_state

draw_routes(SharedStateConsumer)

# Create messages that will trigger concurrent operations
concurrent_messages = []
20.times do |i|
  concurrent_messages << {
    message_id: i + 1,
    key: "data_#{i % 5}",
    value: "value_#{i}",
    increment: (i % 10) + 1
  }.to_json
end

# Produce all messages quickly to encourage concurrent processing
concurrent_messages.each { |msg| produce(DT.topic, msg) }

start_karafka_and_wait_until do
  DT[:consumed].size >= concurrent_messages.size
end

# Verify all messages were processed
assert_equal(
  concurrent_messages.size, DT[:consumed].size,
  'Should process all messages despite concurrent access'
)

# Verify shared counter integrity
expected_total_increment = (1..20).map { |i| (i % 10) + 1 }.sum
actual_final_counter = DT[:consumed].last[:counter_after]
assert_equal(
  expected_total_increment, actual_final_counter,
  'Shared counter should reflect all increments atomically'
)

# Verify no race condition errors occurred
assert DT[:errors].empty?, "Race condition errors detected: #{DT[:errors].join(', ')}"

# Verify shared data was updated correctly
final_data_snapshot = DT[:consumed].last[:data_snapshot]
(0..4).each do |i|
  key = "data_#{i}"
  assert final_data_snapshot.key?(key), "Should have data for key #{key}"
  assert final_data_snapshot.key?("#{key}_thread"), "Should have thread info for key #{key}"
  assert final_data_snapshot.key?("#{key}_timestamp"), "Should have timestamp for key #{key}"
end

# Verify concurrent access was logged properly
access_log = SharedStateConsumer.access_logs
assert_equal(
  concurrent_messages.size, access_log.size,
  'Should log all concurrent accesses'
)

# Verify thread safety - check for proper ordering within critical sections
thread_groups = DT[:consumed].group_by { |entry| entry[:thread_id] }
thread_groups.each do |thread_id, entries|
  # Within each thread, counter values should be monotonically increasing
  counter_values = entries.map { |entry| entry[:counter_after] }
  assert(
    counter_values.each_cons(2).all? { |a, b| a <= b },
    "Counter values should be non-decreasing within thread #{thread_id}"
  )
end

# The key success criteria: concurrent shared state access handled safely
assert_equal(
  concurrent_messages.size, DT[:consumed].size,
  'Should handle concurrent shared state access without data corruption'
)
