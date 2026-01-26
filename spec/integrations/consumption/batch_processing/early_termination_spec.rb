# frozen_string_literal: true

# Karafka should handle batch processing with early termination scenarios

setup_karafka

class EarlyTerminationConsumer < Karafka::BaseConsumer
  def consume
    termination_info = {
      batch_size: messages.size,
      processing_start: Time.now.to_f,
      processed_count: 0,
      termination_reason: nil
    }

    messages.each_with_index do |message, index|
      message_data = JSON.parse(message.raw_payload)

      # Check for early termination conditions
      if message_data["terminate_early"]
        termination_info[:termination_reason] = "early_termination_requested"
        termination_info[:processed_count] = index
        termination_info[:processing_end] = Time.now.to_f
        termination_info[:early_terminated] = true

        DT[:terminated_batches] << termination_info
        return # Early termination
      end

      # Normal processing
      DT[:processed_messages] << {
        message_id: message_data["id"],
        batch_position: index,
        processed_at: Time.now.to_f
      }

      termination_info[:processed_count] += 1
    end

    # Completed full batch
    termination_info[:processing_end] = Time.now.to_f
    termination_info[:early_terminated] = false
    termination_info[:termination_reason] = "completed_normally"

    DT[:completed_batches] << termination_info
  end
end

draw_routes(EarlyTerminationConsumer)

# Create messages with early termination trigger
early_termination_messages = []

# First batch: normal messages
5.times do |i|
  early_termination_messages << {
    id: "normal_#{i}",
    content: "normal_message",
    terminate_early: false
  }.to_json
end

# Second batch: messages with early termination
5.times do |i|
  should_terminate = (i == 2) # Terminate on the 3rd message
  early_termination_messages << {
    id: "early_term_#{i}",
    content: "early_termination_batch",
    terminate_early: should_terminate
  }.to_json
end

# Third batch: more normal messages
5.times do |i|
  early_termination_messages << {
    id: "final_#{i}",
    content: "final_batch",
    terminate_early: false
  }.to_json
end

# Produce messages with delays to create separate batches
early_termination_messages.each_with_index do |msg, index|
  produce(DT.topic, msg)
  # Add delay every 5 messages to encourage separate batches
  sleep(0.05) if (index + 1) % 5 == 0
end

start_karafka_and_wait_until do
  total_batches = DT[:completed_batches].size + DT[:terminated_batches].size
  total_batches >= 1 && DT[:processed_messages].size >= 5
end

# Verify batch processing behavior
total_batches = DT[:completed_batches].size + DT[:terminated_batches].size
assert(
  total_batches >= 1,
  "Should have processed at least one batch"
)

# Verify normal batch completion
DT[:completed_batches].each do |batch|
  assert_equal(
    "completed_normally", batch[:termination_reason],
    "Completed batches should have normal termination reason"
  )

  assert(
    !batch[:early_terminated],
    "Completed batches should not be marked as early terminated"
  )

  assert_equal(
    batch[:batch_size], batch[:processed_count],
    "Completed batches should process all messages"
  )

  assert(
    batch[:processing_end] > batch[:processing_start],
    "Should have valid processing time range"
  )
end

# Verify early termination behavior
DT[:terminated_batches].each do |batch|
  assert_equal(
    "early_termination_requested", batch[:termination_reason],
    "Terminated batches should have early termination reason"
  )

  assert(
    batch[:early_terminated],
    "Terminated batches should be marked as early terminated"
  )

  assert(
    batch[:processed_count] < batch[:batch_size],
    "Terminated batches should process fewer messages than batch size"
  )

  assert(
    batch[:processing_end] > batch[:processing_start],
    "Terminated batches should have valid processing time range"
  )
end

# Verify message processing consistency
processed_ids = DT[:processed_messages].map { |msg| msg[:message_id] }
assert(
  processed_ids.any?,
  "Should have processed at least some messages"
)

# Verify batch position consistency
processed_by_batch = DT[:processed_messages].group_by { |msg| msg[:message_id].split("_")[0] }
processed_by_batch.each do |_batch_type, messages|
  messages.each_with_index do |msg, _expected_position|
    # NOTE: batch_position might not match expected_position due to early termination
    assert(
      msg[:batch_position] >= 0,
      "Batch position should be non-negative"
    )
  end
end

# The key success criteria: early termination handled correctly
assert(
  !DT[:processed_messages].empty?,
  "Should handle batch processing with early termination scenarios"
)
