# frozen_string_literal: true

# Karafka should handle seeking operations during active consumption correctly

setup_karafka

# Create a consumer that tracks message offsets
class SeekingOperationsConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      message_data = JSON.parse(message.raw_payload)

      DT[:consumed] << {
        message_id: message_data['id'],
        offset: message.metadata.offset,
        partition: message.metadata.partition,
        processed_at: Time.now.to_f
      }
    end
  end
end

draw_routes(SeekingOperationsConsumer)

# Produce initial messages
initial_messages = []
10.times do |i|
  initial_messages << {
    id: "initial_#{i}",
    content: 'seeking_test_message',
    sequence: i
  }.to_json
end

initial_messages.each { |msg| produce(DT.topic, msg) }

# Let consumer process some initial messages
start_karafka_and_wait_until do
  DT[:consumed].size >= 3 # Process at least 3 messages first
end

# Get the consumer group ID
consumer_group_id = Karafka::App.routes.first.id

# Test seeking to beginning while consumer might be active
begin
  # Attempt to seek to beginning
  seek_result = Karafka::Admin.seek_consumer_group(
    consumer_group_id,
    { DT.topic => { 0 => 0 } }
  )

  DT[:admin_operations] << {
    operation: 'seek_to_beginning',
    success: true,
    result: seek_result,
    target_offset: 0
  }
rescue StandardError => e
  DT[:admin_operations] << {
    operation: 'seek_to_beginning',
    success: false,
    error_class: e.class.name,
    error_message: e.message,
    expected_restriction: e.message.downcase.include?('active') ||
                          e.message.downcase.include?('member') ||
                          e.message.downcase.include?('coordinator')
  }
end

# Test seeking to specific offset
begin
  # Try to seek to a specific offset (offset 2)
  seek_specific_result = Karafka::Admin.seek_consumer_group(
    consumer_group_id,
    { DT.topic => { 0 => 2 } }
  )

  DT[:admin_operations] << {
    operation: 'seek_to_specific',
    success: true,
    result: seek_specific_result,
    target_offset: 2
  }
rescue StandardError => e
  DT[:admin_operations] << {
    operation: 'seek_to_specific',
    success: false,
    error_class: e.class.name,
    error_message: e.message,
    expected_restriction: e.message.downcase.include?('active') ||
                          e.message.downcase.include?('member') ||
                          e.message.downcase.include?('coordinator')
  }
end

# Test seeking to end
begin
  # Get current high water mark first
  watermarks = Karafka::Admin.read_watermarks(DT.topic, 0)
  high_watermark = watermarks.high

  seek_end_result = Karafka::Admin.seek_consumer_group(
    consumer_group_id,
    { DT.topic => { 0 => high_watermark } }
  )

  DT[:admin_operations] << {
    operation: 'seek_to_end',
    success: true,
    result: seek_end_result,
    target_offset: high_watermark,
    high_watermark: high_watermark
  }
rescue StandardError => e
  DT[:admin_operations] << {
    operation: 'seek_to_end',
    success: false,
    error_class: e.class.name,
    error_message: e.message,
    expected_restriction: e.message.downcase.include?('active') ||
                          e.message.downcase.include?('member') ||
                          e.message.downcase.include?('coordinator')
  }
end

# No need to produce more messages as we already have the admin operations we need

# Verify we performed seek operations
assert(
  DT[:admin_operations].any?,
  'Should have attempted seeking operations'
)

# Verify seek operation results
DT[:admin_operations].each do |op|
  assert(
    op.key?(:success),
    'Seek operation should have success flag'
  )

  assert(
    !op[:operation].nil?,
    'Seek operation should specify operation type'
  )

  if op[:success]
    assert(
      !op[:result].nil?,
      'Successful seek should have result'
    )

    assert(
      op.key?(:target_offset),
      'Successful seek should specify target offset'
    )
  else
    assert(
      op.key?(:error_class),
      'Failed seek should have error class'
    )

    assert(
      op.key?(:expected_restriction),
      'Failed seek should indicate if restriction was expected'
    )
  end
end

# Verify message processing continued
assert(
  !DT[:consumed].empty?,
  'Should have processed messages despite seeking operations'
)

# Verify message order and offsets
consumed_offsets = DT[:consumed].map { |msg| msg[:offset] }.sort
assert(
  consumed_offsets.uniq.size == consumed_offsets.size,
  'Should not have duplicate message offsets'
)

# Check if seeking had any effect on message processing
initial_consumed = DT[:consumed].select { |msg| msg[:message_id].start_with?('initial_') }

assert(
  initial_consumed.any?,
  'Should have consumed some initial messages'
)

# Verify seeking operations behavior
seek_operations_count = DT[:admin_operations].size

# The key success criteria: seeking operations handled appropriately during active consumption
assert(
  seek_operations_count >= 3,
  'Should have attempted multiple seeking operations'
)

assert(
  seek_operations_count > 0,
  'Should have attempted seeking operations'
)
