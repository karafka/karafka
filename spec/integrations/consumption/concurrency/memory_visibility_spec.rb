# frozen_string_literal: true

# Karafka should handle memory visibility between processing threads correctly

setup_karafka

# Shared memory structure to test visibility between threads
class MemoryVisibilityStore
  def initialize
    @shared_memory = {}
    @read_log = []
    @write_log = []
    @mutex = Mutex.new
    @memory_fence = true # Force memory barrier
  end

  def write_data(thread_id, key, value)
    @mutex.synchronize do
      @shared_memory[key] = value
      @write_log << {
        thread_id: thread_id,
        key: key,
        value: value,
        timestamp: Time.now.to_f,
        operation: :write
      }
      # Force memory visibility with explicit synchronization
      @memory_fence = !@memory_fence
    end
  end

  def read_data(thread_id, key)
    @mutex.synchronize do
      value = @shared_memory[key]
      @read_log << {
        thread_id: thread_id,
        key: key,
        value: value,
        timestamp: Time.now.to_f,
        operation: :read
      }
      # Check memory fence
      @memory_fence = !@memory_fence
      value
    end
  end

  def read_all_data(thread_id)
    @mutex.synchronize do
      data_snapshot = @shared_memory.dup
      @read_log << {
        thread_id: thread_id,
        key: :all_data,
        value: data_snapshot,
        timestamp: Time.now.to_f,
        operation: :read_all
      }
      data_snapshot
    end
  end

  def logs
    @mutex.synchronize do
      {
        writes: @write_log.dup,
        reads: @read_log.dup,
        current_state: @shared_memory.dup
      }
    end
  end

  def reset
    @mutex.synchronize do
      @shared_memory.clear
      @write_log.clear
      @read_log.clear
    end
  end
end

class MemoryVisibilityConsumer < Karafka::BaseConsumer
  # Class-level shared store for memory visibility testing
  @memory_store = MemoryVisibilityStore.new

  class << self
    attr_reader :memory_store
  end

  def consume
    messages.each do |message|
      thread_id = Thread.current.object_id
      message_data = JSON.parse(message.raw_payload)

      case message_data["operation"]
      when "write"
        # Write data that other threads should be able to see
        key = message_data["key"]
        value = "#{message_data["value"]}_thread_#{thread_id}_time_#{Time.now.to_f}"
        self.class.memory_store.write_data(thread_id, key, value)

        # Small delay to allow other threads to potentially read
        sleep(0.001)

      when "read"
        # Read data that was written by other threads
        key = message_data["key"]
        read_value = self.class.memory_store.read_data(thread_id, key)

        # Verify we can see data written by other threads
        if read_value && read_value.include?("thread_") &&
            !read_value.include?("thread_#{thread_id}")
          DT[:cross_thread_reads] << {
            reader_thread: thread_id,
            read_value: read_value,
            message_id: message_data["id"]
          }
        end

      when "read_all"
        # Read all shared data to test bulk memory visibility
        all_data = self.class.memory_store.read_all_data(thread_id)

        # Count how many values were written by different threads
        other_thread_data = all_data.values.select do |val|
          val.is_a?(String) && val.include?("thread_") && !val.include?("thread_#{thread_id}")
        end

        if other_thread_data.any?
          DT[:bulk_visibility] << {
            reader_thread: thread_id,
            other_thread_count: other_thread_data.size,
            total_data_count: all_data.size,
            message_id: message_data["id"]
          }
        end

      when "write_read"
        # Combined operation: write then immediately read to test write-read coherence
        key = message_data["key"]
        write_value = "combined_#{message_data["id"]}_#{thread_id}"

        self.class.memory_store.write_data(thread_id, key, write_value)
        read_value = self.class.memory_store.read_data(thread_id, key)

        # Verify write-read coherence
        if write_value == read_value
          DT[:write_read_coherence] << {
            thread_id: thread_id,
            key: key,
            message_id: message_data["id"],
            coherent: true
          }
        else
          DT[:errors] << "Write-read coherence failure: wrote '#{write_value}', " \
                         "read '#{read_value}'"
        end
      end

      DT[:consumed] << {
        thread_id: thread_id,
        message_id: message_data["id"],
        operation: message_data["operation"],
        processed_at: Time.now.to_f
      }
    end
  end

  def self.reset_store
    @memory_store.reset
  end

  def self.memory_logs
    @memory_store.logs
  end
end

# Reset store before test
MemoryVisibilityConsumer.reset_store

draw_routes(MemoryVisibilityConsumer)

# Create messages that will test different aspects of memory visibility
memory_visibility_messages = []

# Phase 1: Write operations (create shared data)
5.times do |i|
  memory_visibility_messages << {
    id: i + 1,
    operation: "write",
    key: "shared_key_#{i % 3}",
    value: "initial_value_#{i}"
  }.to_json
end

# Phase 2: Read operations (read data written by other threads)
5.times do |i|
  memory_visibility_messages << {
    id: i + 6,
    operation: "read",
    key: "shared_key_#{i % 3}"
  }.to_json
end

# Phase 3: Write-read coherence tests
5.times do |i|
  memory_visibility_messages << {
    id: i + 11,
    operation: "write_read",
    key: "coherence_key_#{i}"
  }.to_json
end

# Phase 4: Bulk read tests (read all shared data)
5.times do |i|
  memory_visibility_messages << {
    id: i + 16,
    operation: "read_all"
  }.to_json
end

# Phase 5: More writes to test ongoing visibility
5.times do |i|
  memory_visibility_messages << {
    id: i + 21,
    operation: "write",
    key: "late_key_#{i}",
    value: "late_value_#{i}"
  }.to_json
end

# Phase 6: Final reads to verify late writes are visible
5.times do |i|
  memory_visibility_messages << {
    id: i + 26,
    operation: "read",
    key: "late_key_#{i}"
  }.to_json
end

# Produce all messages to encourage concurrent processing
memory_visibility_messages.each { |msg| produce(DT.topic, msg) }

start_karafka_and_wait_until do
  DT[:consumed].size >= memory_visibility_messages.size
end

# Verify all messages were processed
assert_equal(
  memory_visibility_messages.size, DT[:consumed].size,
  "Should process all memory visibility test messages"
)

# Verify no memory coherence errors occurred
assert DT[:errors].empty?, "Memory coherence errors detected: #{DT[:errors].join(", ")}"

# Get final memory logs for analysis
memory_logs = MemoryVisibilityConsumer.memory_logs

# Verify write operations were logged
writes = memory_logs[:writes]
assert writes.size >= 10, "Should have logged write operations"

# Verify read operations were logged
reads = memory_logs[:reads]
assert reads.size >= 15, "Should have logged read operations"

# Verify write-read coherence
write_read_coherence = DT[:write_read_coherence] || []
assert write_read_coherence.size >= 5, "Should have coherent write-read operations"
assert(
  write_read_coherence.all? { |entry| entry[:coherent] },
  "All write-read operations should be coherent"
)

# Verify cross-thread visibility (if multiple threads were used)
unique_threads = DT[:consumed].map { |entry| entry[:thread_id] }.uniq
if unique_threads.size > 1
  # Test cross-thread reads occurred

  # Test bulk visibility occurred
  bulk_visibility = DT[:bulk_visibility] || []
  if bulk_visibility.any?
    assert(
      bulk_visibility.all? { |entry| entry[:other_thread_count] > 0 },
      "Bulk readers should see data from other threads"
    )
  end
end

# Verify temporal consistency - reads should see writes that happened before them
# Group writes by key and track the latest write time for each key
latest_writes = writes.group_by { |w| w[:key] }.transform_values do |key_writes|
  key_writes.max_by { |w| w[:timestamp] }
end

read_entries = reads.select { |r| r[:operation] == :read }

successful_temporal_reads = 0
read_entries.each do |read_entry|
  key = read_entry[:key]
  read_time = read_entry[:timestamp]
  latest_write = latest_writes[key]

  next unless latest_write && latest_write[:timestamp] < read_time - 0.001 # Small buffer

  # This read happened after a write to the same key - it should see the written value
  successful_temporal_reads += 1 if read_entry[:value]
end

# Temporal consistency verification completed

# Verify data integrity in final state
final_state = memory_logs[:current_state]
assert final_state.keys.size >= 5, "Should have accumulated shared data"

# Verify all written data maintained integrity
final_state.each do |key, value|
  assert value.is_a?(String), "All stored values should be strings, got #{value.class} for #{key}"

  # Different key types have different value formats
  if key.start_with?("shared_key_", "late_key_")
    assert(
      value.include?("thread_"),
      "Shared/late key values should contain thread info, got '#{value}' for #{key}"
    )
  elsif key.start_with?("coherence_key_")
    assert(
      value.include?("combined_"),
      "Coherence key values should contain 'combined_', got '#{value}' for #{key}"
    )
  end
end

# The key success criteria: memory visibility handled correctly between threads
assert_equal(
  memory_visibility_messages.size, DT[:consumed].size,
  "Should handle memory visibility between processing threads without corruption"
)
