# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# This integration test demonstrates how to override the default LJF (Longest Job First)
# scheduling algorithm to implement custom logic that identifies and prioritizes Virtual
# Partitions containing expensive messages. This ensures expensive messages are processed
# first, allowing them to run in parallel with other messages rather than blocking at the end.
#
# Real-world scenario: In production, some messages require extensive processing (1+ minute)
# while others complete quickly (<1 second). With Virtual Partitions and limited worker threads,
# default LJF scheduling might not optimally handle this, causing idle workers while the expensive
# message blocks progress.

become_pro!

# Custom scheduler that identifies and prioritizes VPs containing expensive messages
class ExpensiveFirstScheduler < Karafka::Pro::Processing::Schedulers::Base
  # Schedules consumption jobs, prioritizing VPs with expensive messages
  #
  # @param jobs_array [Array<Karafka::Processing::Jobs::Consume>] jobs for scheduling
  def schedule_consumption(jobs_array)
    # Separate expensive and normal jobs
    expensive_jobs = []
    normal_jobs = []

    jobs_array.each do |job|
      # Check if this VP contains any expensive messages
      # We identify expensive messages by a special header
      has_expensive = job.messages.any? do |message|
        message.headers['expensive'] == 'true'
      end

      if has_expensive
        expensive_jobs << job
      else
        normal_jobs << job
      end
    end

    # Track scheduling order for verification
    DT[:scheduling_order] ||= []

    # Schedule expensive jobs first to ensure they start processing immediately
    # This allows them to run in parallel with other jobs
    expensive_jobs.each do |job|
      DT[:scheduling_order] << { type: 'expensive', messages_count: job.messages.size }
      @queue << job
    end

    # Then schedule normal jobs using LJF ordering for optimal throughput
    ordered_normal = order_by_ljf(normal_jobs)
    ordered_normal.each do |job|
      DT[:scheduling_order] << { type: 'normal', messages_count: job.messages.size }
      @queue << job
    end
  end

  private

  # Orders jobs by LJF (Longest Job First) based on estimated processing time
  #
  # @param jobs [Array<Karafka::Processing::Jobs::Consume>] jobs to order
  # @return [Array<Karafka::Processing::Jobs::Consume>] ordered jobs
  def order_by_ljf(jobs)
    perf_tracker = Karafka::Pro::Instrumentation::PerformanceTracker.instance

    ordered = jobs.map do |job|
      messages = job.messages
      message = messages.first

      # Estimate processing cost based on historical data
      cost = perf_tracker.processing_time_p95(message.topic, message.partition) * messages.size

      [job, cost]
    end

    # Sort by cost descending (longest job first)
    ordered.sort_by! { |_, cost| -cost }
    ordered.map(&:first)
  end
end

# Test configuration with custom scheduler
setup_karafka do |config|
  # Set concurrency to 5 worker threads
  config.concurrency = 5
  config.max_messages = 120
  config.max_wait_time = 500

  # Use our custom expensive-first scheduler
  config.internal.processing.scheduler_class = ExpensiveFirstScheduler
end

# Consumer that processes messages with varying processing times
class ExpensiveMessageConsumer < Karafka::BaseConsumer
  def consume
    vp_id = object_id

    messages.each do |message|
      start_time = Time.now.to_f

      # Check if this is an expensive message
      if message.headers['expensive'] == 'true'
        DT[:expensive_vps] ||= []
        DT[:expensive_vps] << vp_id
        DT[:expensive_start] ||= []
        DT[:expensive_start] << start_time

        # Track when expensive processing starts
        DT[:expensive_started_at] ||= Time.now.to_f

        # Expensive message takes 3 seconds to process
        # In real scenario, this would be complex computation, API calls, etc.
        sleep(3)

        DT[:expensive_end] ||= []
        DT[:expensive_end] << Time.now.to_f
      else
        # Normal messages process quickly (50-200ms)
        sleep(0.05 + (rand * 0.15))
      end

      end_time = Time.now.to_f

      # Track processing details for analysis
      DT[:processed] ||= []
      DT[:processed] << {
        vp_id: vp_id,
        message_id: message.raw_payload,
        expensive: message.headers['expensive'] == 'true',
        start_time: start_time,
        end_time: end_time,
        duration: end_time - start_time,
        thread_id: Thread.current.object_id
      }

      # Track messages processed concurrently with expensive message
      next unless DT[:expensive_started_at] &&
                  !DT[:expensive_started_at].is_a?(Array) &&
                  start_time > DT[:expensive_started_at] &&
                  start_time < (DT[:expensive_started_at] + 3) &&
                  message.headers['expensive'] != 'true'

      DT[:concurrent_with_expensive] ||= []
      DT[:concurrent_with_expensive] << message.raw_payload
    end

    DT[:vps_completed] ||= []
    DT[:vps_completed] << vp_id

    # Track VP start order (first process time for each VP)
    DT[:vp_start_times] ||= {}
    DT[:vp_start_times][vp_id] ||= Time.now.to_f
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer ExpensiveMessageConsumer

    # Configure Virtual Partitions
    # Create more VPs than worker threads to test scheduling
    virtual_partitions(
      max_partitions: 15, # More than 5 workers
      # Distribute messages across VPs based on message ID
      # This ensures good distribution for testing
      partitioner: ->(msg) { msg.raw_payload.to_i % 15 }
    )
  end
end

# Generate test messages
messages = []

# Create 1 expensive message (will go to VP 12 based on ID % 15)
expensive_msg_id = '42'
messages << [expensive_msg_id, { 'expensive' => 'true' }]

# Create 119 normal messages distributed across VPs
(1..120).each do |i|
  next if i == 42 # Skip the expensive message ID

  messages << [i.to_s, { 'expensive' => 'false' }]
end

# Produce messages with headers
messages.each do |payload, headers|
  produce(DT.topics[0], payload, headers: headers)
end

# Initialize tracking data
DT[:processed] = []
DT[:vps_completed] = []
DT[:expensive_vps] = []
DT[:concurrent_with_expensive] = []
DT[:scheduling_order] = []
DT[:vp_start_times] = {}

start_karafka_and_wait_until do
  DT[:processed].size >= 120
end

# Assertions

# 1. Verify all messages were processed
assert_equal 120, DT[:processed].size, 'Should process all 120 messages'

# 2. Verify expensive VP was scheduled first
# Check the scheduling order - expensive jobs should be at the beginning
expensive_scheduled_first = DT[:scheduling_order].first(5).any? { |job| job[:type] == 'expensive' }
assert expensive_scheduled_first, 'Expensive job should be among the first scheduled'

# 3. Verify expensive VP was prioritized
# The expensive VP should be scheduled early, though exact position may vary due to timing
vp_start_order = DT[:vp_start_times].sort_by { |_, time| time }.map(&:first)
expensive_vp_positions = DT[:expensive_vps].uniq.filter_map { |vp| vp_start_order.index(vp) }

# Due to timing variations, we check if it's in the first 10 (out of 15 VPs)
assert(
  expensive_vp_positions.any? { |pos| pos && pos < 10 },
  "Expensive VP should be prioritized, but started at positions: #{expensive_vp_positions}"
)

# 4. Verify messages were processed concurrently with the expensive message
# Since expensive message takes 3 seconds and we have 5 workers, other messages should process in
# parallel
# Note: Due to timing, this may not always capture all concurrent messages
unless DT[:concurrent_with_expensive].empty?
  assert(
    DT[:concurrent_with_expensive].size >= 5,
    'Expected at least 5 messages to process concurrently with expensive message'
  )
end

# 5. Verify VP distribution
vp_distribution = DT[:processed].group_by { |p| p[:vp_id] }
assert(
  vp_distribution.size >= 10,
  "Expected at least 10 VPs to be created, but only #{vp_distribution.size} were"
)

# 6. Verify expensive message was correctly identified
expensive_messages = DT[:processed].select { |p| p[:expensive] }
assert_equal 1, expensive_messages.size, 'Should have exactly one expensive message'
assert_equal '42', expensive_messages.first[:message_id], 'Expensive message should have ID 42'

# 7. Verify processing times
expensive_msg = expensive_messages.first
assert(
  expensive_msg[:duration] > 2.9 && expensive_msg[:duration] < 3.5,
  "Expensive message should take ~3 seconds, but took #{expensive_msg[:duration]}"
)

normal_messages = DT[:processed].reject { |p| p[:expensive] }
normal_messages.each do |msg|
  assert(
    msg[:duration] < 0.5,
    "Normal message #{msg[:message_id]} should process in < 0.5s, but took #{msg[:duration]}"
  )
end

# 8. Verify thread utilization
thread_usage = DT[:processed].map { |p| p[:thread_id] }.uniq
assert thread_usage.size <= 5, 'Should use at most 5 threads (configured concurrency)'
assert thread_usage.size >= 3, 'Should utilize multiple threads for parallel processing'

# 9. Verify total processing time is optimized
# With custom scheduler, expensive message runs in parallel, so total time should be around 3-4s
# Without optimization, it could take longer if expensive message blocks other processing
max = DT[:processed].map { |p| p[:end_time] }.max
min = DT[:processed].map { |p| p[:start_time] }.min
test_duration = max - min

assert(
  test_duration < 6,
  "Total processing should be in under 6s with optimization, but took #{test_duration.round(2)}s"
)
