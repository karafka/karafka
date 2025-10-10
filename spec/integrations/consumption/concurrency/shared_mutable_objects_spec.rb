# frozen_string_literal: true

# Karafka should handle message processing with shared mutable objects safely

setup_karafka

# Shared mutable objects that simulate real-world scenarios
class SharedDataStore
  def initialize
    @data = {}
    @access_count = 0
    @operations = []
    @mutex = Mutex.new
  end

  def increment_counter(key, amount)
    @mutex.synchronize do
      @data[key] = (@data[key] || 0) + amount
      @access_count += 1
      @operations << {
        operation: :increment, key: key, amount: amount, thread: Thread.current.object_id
      }
    end
  end

  def append_to_list(key, value)
    @mutex.synchronize do
      @data[key] = (@data[key] || [])
      @data[key] << value
      @access_count += 1
      @operations << {
        operation: :append, key: key, value: value, thread: Thread.current.object_id
      }
    end
  end

  def snapshot
    @mutex.synchronize do
      {
        data: @data.dup,
        access_count: @access_count,
        operations: @operations.dup
      }
    end
  end

  def reset
    @mutex.synchronize do
      @data.clear
      @access_count = 0
      @operations.clear
    end
  end
end

class SharedMutableObjectsConsumer < Karafka::BaseConsumer
  # Class-level shared store
  @shared_store = SharedDataStore.new

  class << self
    attr_reader :shared_store
  end

  def consume
    messages.each do |message|
      thread_id = Thread.current.object_id
      message_data = JSON.parse(message.raw_payload)

      case message_data['operation']
      when 'increment'
        self.class.shared_store.increment_counter(message_data['key'], message_data['amount'])

      when 'append'
        self.class.shared_store.append_to_list(message_data['key'], message_data['value'])

      when 'mixed'
        # Perform multiple operations to test compound thread safety
        # Extract counter key from mixed_0, mixed_1, mixed_2 to counter_0, counter_1, counter_2
        counter_key = message_data['key'].sub('mixed_', 'counter_')
        self.class.shared_store.increment_counter(counter_key, 1)
        self.class.shared_store.append_to_list(
          "#{message_data['key']}_list", message_data['value']
        )
      end

      # Capture snapshot for verification
      snapshot = self.class.shared_store.snapshot

      DT[:consumed] << {
        thread_id: thread_id,
        message_id: message_data['id'],
        operation: message_data['operation'],
        data_snapshot: snapshot[:data].dup,
        access_count: snapshot[:access_count],
        operations_count: snapshot[:operations].size
      }
    end
  end

  class << self
    def reset_store
      @shared_store.reset
    end

    def final_snapshot
      @shared_store.snapshot
    end
  end
end

# Reset store before test
SharedMutableObjectsConsumer.reset_store

draw_routes(SharedMutableObjectsConsumer)

# Create messages with different operations to test concurrent mutable object access
test_messages = []

# Increment operations
10.times do |i|
  test_messages << {
    id: i + 1,
    operation: 'increment',
    key: "counter_#{i % 3}",
    amount: i + 1
  }.to_json
end

# Append operations
10.times do |i|
  test_messages << {
    id: i + 11,
    operation: 'append',
    key: "list_#{i % 3}",
    value: "item_#{i}"
  }.to_json
end

# Mixed operations
10.times do |i|
  test_messages << {
    id: i + 21,
    operation: 'mixed',
    key: "mixed_#{i % 3}",
    value: "mixed_item_#{i}"
  }.to_json
end

# Produce all messages to encourage concurrent processing
test_messages.each { |msg| produce(DT.topic, msg) }

start_karafka_and_wait_until do
  DT[:consumed].size >= test_messages.size
end

# Verify all messages were processed
assert_equal(
  test_messages.size, DT[:consumed].size,
  'Should process all messages despite concurrent mutable object access'
)

# Get final state
final_snapshot = SharedMutableObjectsConsumer.final_snapshot

# Verify increment operations worked correctly
# counter_0: messages 1,4,7,10 (amounts 1,4,7,10) + mixed operations 21,24,27,30 (each +1)
expected_counter_0 = [1, 4, 7, 10].sum + 4 # +4 from mixed operations
# counter_1: messages 2,5,8 (amounts 2,5,8) + mixed operations 22,25,28 (each +1)
expected_counter_1 = [2, 5, 8].sum + 3 # +3 from mixed operations
# counter_2: messages 3,6,9 (amounts 3,6,9) + mixed operations 23,26,29 (each +1)
expected_counter_2 = [3, 6, 9].sum + 3 # +3 from mixed operations

assert_equal(
  expected_counter_0, final_snapshot[:data]['counter_0'],
  'Counter 0 should reflect all concurrent increments'
)
assert_equal(
  expected_counter_1, final_snapshot[:data]['counter_1'],
  'Counter 1 should reflect all concurrent increments'
)
assert_equal(
  expected_counter_2, final_snapshot[:data]['counter_2'],
  'Counter 2 should reflect all concurrent increments'
)

# Verify append operations worked correctly
(0..2).each do |i|
  list_key = "list_#{i}"
  expected_items = (0..9).select { |j| j % 3 == i }.map { |j| "item_#{j}" }
  actual_items = final_snapshot[:data][list_key] || []

  assert_equal(
    expected_items.size, actual_items.size,
    "List #{i} should have correct number of items"
  )

  # All expected items should be present (order may vary due to concurrency)
  expected_items.each do |item|
    assert(
      actual_items.include?(item),
      "List #{i} should contain #{item}"
    )
  end

  # Verify mixed operations created additional data
  mixed_list_key = "mixed_#{i}_list"
  expected_items = (0..9).select { |j| j % 3 == i }.map { |j| "mixed_item_#{j}" }
  actual_items = final_snapshot[:data][mixed_list_key] || []

  assert_equal(
    expected_items.size, actual_items.size,
    "Mixed list #{i} should have correct number of items"
  )
end

# Verify total access count reflects all operations
# 10 increments + 10 appends + 10 mixed (each mixed = 2 operations) = 40 total operations
expected_total_operations = 40
assert_equal(
  expected_total_operations, final_snapshot[:access_count],
  'Access count should reflect all concurrent operations'
)

# Verify no data corruption occurred by checking operation count
assert_equal(
  expected_total_operations, final_snapshot[:operations].size,
  'All operations should be recorded atomically'
)

# Verify concurrent access patterns
access_counts_by_message = DT[:consumed].map { |entry| entry[:access_count] }
# Access counts should be monotonically increasing
assert(
  access_counts_by_message.each_cons(2).all? { |a, b| a <= b },
  'Access counts should be monotonically increasing due to synchronization'
)

# The key success criteria: shared mutable objects handled safely
assert_equal(
  test_messages.size, DT[:consumed].size,
  'Should handle concurrent access to shared mutable objects without corruption'
)
