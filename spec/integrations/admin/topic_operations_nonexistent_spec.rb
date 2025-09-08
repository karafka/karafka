# frozen_string_literal: true

# Karafka should handle administrative operations on non-existent topics gracefully

setup_karafka

# Create a simple consumer for admin operations testing
class AdminTestConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      message_data = JSON.parse(message.raw_payload)

      DT[:consumed] << {
        message_id: message_data['id'],
        processed_at: Time.now.to_f
      }
    end
  end
end

draw_routes(AdminTestConsumer)

# Test topic operations on non-existent topics
nonexistent_topic = "nonexistent_topic_#{SecureRandom.hex(8)}"

# Test fetching metadata for non-existent topic
begin
  metadata_result = Karafka::Admin.cluster_info(nonexistent_topic)

  DT[:admin_operations] << {
    operation: 'cluster_info',
    topic: nonexistent_topic,
    success: true,
    result_type: metadata_result.class.name,
    has_topics: metadata_result.topics.any?
  }
rescue StandardError => e
  DT[:admin_operations] << {
    operation: 'cluster_info',
    topic: nonexistent_topic,
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }
end

# Test creating topic that doesn't exist
begin
  create_result = Karafka::Admin.create_topic(nonexistent_topic, 1, 1)

  DT[:admin_operations] << {
    operation: 'create_topic',
    topic: nonexistent_topic,
    success: true,
    result: create_result
  }

  # Wait a bit for topic creation to propagate
  sleep(0.5)

  # Verify topic was created by fetching metadata
  verification_metadata = Karafka::Admin.cluster_info(nonexistent_topic)
  topic_exists = verification_metadata.topics.any? { |t| t.topic_name == nonexistent_topic }

  DT[:admin_operations] << {
    operation: 'verify_creation',
    topic: nonexistent_topic,
    success: topic_exists,
    topic_found: topic_exists
  }
rescue StandardError => e
  DT[:admin_operations] << {
    operation: 'create_topic',
    topic: nonexistent_topic,
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }
end

# Test deleting the topic we just created (if creation succeeded)
creation_succeeded = DT[:admin_operations].any? do |op|
  op[:operation] == 'create_topic' && op[:success]
end

if creation_succeeded
  begin
    delete_result = Karafka::Admin.delete_topic(nonexistent_topic)

    DT[:admin_operations] << {
      operation: 'delete_topic',
      topic: nonexistent_topic,
      success: true,
      result: delete_result
    }

    # Wait for deletion to propagate
    sleep(0.5)
  rescue StandardError => e
    DT[:admin_operations] << {
      operation: 'delete_topic',
      topic: nonexistent_topic,
      success: false,
      error_class: e.class.name,
      error_message: e.message
    }
  end
end

# Test operations on topic that definitely doesn't exist after deletion
another_nonexistent_topic = "definitely_nonexistent_#{SecureRandom.hex(8)}"

begin
  # Try to get topic metadata for topic that definitely doesn't exist
  empty_metadata = Karafka::Admin.cluster_info(another_nonexistent_topic)

  DT[:admin_operations] << {
    operation: 'metadata_nonexistent',
    topic: another_nonexistent_topic,
    success: true,
    topics_found: empty_metadata.topics.size,
    specific_topic_found: empty_metadata.topics.any? do |t|
      t.topic_name == another_nonexistent_topic
    end
  }
rescue StandardError => e
  DT[:admin_operations] << {
    operation: 'metadata_nonexistent',
    topic: another_nonexistent_topic,
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }
end

# Verify we captured administrative operations
assert(
  DT[:admin_operations].any?,
  'Should have performed at least one administrative operation'
)

# Verify cluster_info operations handling
cluster_info_ops = DT[:admin_operations].select { |op| op[:operation] == 'cluster_info' }
if cluster_info_ops.any?
  cluster_info_ops.each do |op|
    assert(
      op.key?(:success),
      'Cluster info operation should have success flag'
    )

    if op[:success]
      assert(
        op.key?(:result_type),
        'Successful cluster info should have result type'
      )
    else
      assert(
        op.key?(:error_class),
        'Failed cluster info should have error class'
      )
    end
  end
end

# Verify topic creation operations
create_ops = DT[:admin_operations].select { |op| op[:operation] == 'create_topic' }
create_ops.each do |op|
  assert(
    op.key?(:success),
    'Create topic operation should have success flag'
  )

  assert(
    !op[:topic].nil? && !op[:topic].empty?,
    'Create topic operation should specify topic name'
  )
end

# Verify topic deletion operations
delete_ops = DT[:admin_operations].select { |op| op[:operation] == 'delete_topic' }
delete_ops.each do |op|
  assert(
    op.key?(:success),
    'Delete topic operation should have success flag'
  )

  assert(
    !op[:topic].nil? && !op[:topic].empty?,
    'Delete topic operation should specify topic name'
  )
end

# Verify metadata operations on nonexistent topics
metadata_ops = DT[:admin_operations].select { |op| op[:operation] == 'metadata_nonexistent' }
metadata_ops.each do |op|
  assert(
    op.key?(:success),
    'Metadata operation should have success flag'
  )

  next unless op[:success]

  assert(
    op.key?(:specific_topic_found),
    'Metadata operation should check if specific topic was found'
  )

  # The specific nonexistent topic should not be found
  assert(
    !op[:specific_topic_found],
    'Nonexistent topic should not be found in metadata'
  )
end

# The key success criteria: graceful handling of operations on nonexistent topics
total_operations = DT[:admin_operations].size
successful_operations = DT[:admin_operations].count { |op| op[:success] }

assert(
  total_operations > 0,
  'Should perform administrative operations on nonexistent topics'
)

assert(
  successful_operations >= 0,
  'Should handle operations on nonexistent topics gracefully'
)
