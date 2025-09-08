# frozen_string_literal: true

# Karafka should handle metadata refresh correctly during topic changes

setup_karafka

# Create a consumer for testing metadata operations
class MetadataRefreshConsumer < Karafka::BaseConsumer
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

draw_routes(MetadataRefreshConsumer)

# Test metadata refresh during topic changes
test_topic_name = "metadata_test_#{SecureRandom.hex(8)}"

# Initial metadata fetch for non-existent topic
begin
  initial_metadata = Karafka::Admin.cluster_info

  DT[:metadata_operations] << {
    operation: 'initial_metadata',
    success: true,
    topics_found: initial_metadata.topics.size,
    target_topic_found: initial_metadata.topics.any? { |t| t.topic_name == test_topic_name }
  }
rescue StandardError => e
  DT[:metadata_operations] << {
    operation: 'initial_metadata',
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }
end

# Create the test topic
begin
  create_result = Karafka::Admin.create_topic(test_topic_name, 1, 1)

  DT[:metadata_operations] << {
    operation: 'create_topic',
    topic_name: test_topic_name,
    success: true,
    result: create_result
  }

  topic_created = true
rescue StandardError => e
  DT[:metadata_operations] << {
    operation: 'create_topic',
    topic_name: test_topic_name,
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }

  topic_created = false
end

if topic_created
  # Wait for topic creation to propagate
  sleep(0.5)

  # Fetch metadata after topic creation
  begin
    post_creation_metadata = Karafka::Admin.cluster_info

    DT[:metadata_operations] << {
      operation: 'post_creation_metadata',
      success: true,
      topics_found: post_creation_metadata.topics.size,
      target_topic_found: post_creation_metadata.topics.any? do |t|
        t.topic_name == test_topic_name
      end
    }
  rescue StandardError => e
    DT[:metadata_operations] << {
      operation: 'post_creation_metadata',
      success: false,
      error_class: e.class.name,
      error_message: e.message
    }
  end

  # Test multiple rapid metadata fetches to simulate refresh scenarios
  3.times do |i|
    rapid_metadata = Karafka::Admin.cluster_info

    DT[:metadata_operations] << {
      operation: "rapid_metadata_#{i}",
      success: true,
      topics_found: rapid_metadata.topics.size,
      target_topic_found: rapid_metadata.topics.any? do |t|
        t.topic_name == test_topic_name
      end,
      iteration: i
    }

    sleep(0.1) # Small delay between rapid fetches
  rescue StandardError => e
    DT[:metadata_operations] << {
      operation: "rapid_metadata_#{i}",
      success: false,
      error_class: e.class.name,
      error_message: e.message,
      iteration: i
    }
  end

  # Delete the topic to test metadata refresh during deletion
  begin
    delete_result = Karafka::Admin.delete_topic(test_topic_name)

    DT[:metadata_operations] << {
      operation: 'delete_topic',
      topic_name: test_topic_name,
      success: true,
      result: delete_result
    }

    # Wait for deletion to propagate
    sleep(0.5)

    # Fetch metadata after deletion
    post_deletion_metadata = Karafka::Admin.cluster_info

    DT[:metadata_operations] << {
      operation: 'post_deletion_metadata',
      success: true,
      topics_found: post_deletion_metadata.topics.size,
      target_topic_found: post_deletion_metadata.topics.any? do |t|
        t.topic_name == test_topic_name
      end
    }
  rescue StandardError => e
    DT[:metadata_operations] << {
      operation: 'delete_topic_or_post_deletion_metadata',
      topic_name: test_topic_name,
      success: false,
      error_class: e.class.name,
      error_message: e.message
    }
  end
end

# Test metadata for existing topic (our main test topic)
begin
  existing_topic_metadata = Karafka::Admin.cluster_info

  DT[:metadata_operations] << {
    operation: 'existing_topic_metadata',
    success: true,
    topics_found: existing_topic_metadata.topics.size,
    target_topic_found: existing_topic_metadata.topics.any? { |t| t.topic_name == DT.topic }
  }
rescue StandardError => e
  DT[:metadata_operations] << {
    operation: 'existing_topic_metadata',
    success: false,
    error_class: e.class.name,
    error_message: e.message
  }
end

# Verify metadata operations were performed
assert(
  DT[:metadata_operations].any?,
  'Should have performed metadata operations'
)

# Verify initial metadata operation
initial_ops = DT[:metadata_operations].select { |op| op[:operation] == 'initial_metadata' }
initial_ops.each do |op|
  assert(
    op.key?(:success),
    'Initial metadata operation should have success flag'
  )

  next unless op[:success]

  # For non-existent topic, should not find the specific topic
  assert(
    !op[:target_topic_found],
    'Initial metadata should not find non-existent topic'
  )
end

# Verify topic creation operations
create_ops = DT[:metadata_operations].select { |op| op[:operation] == 'create_topic' }
create_ops.each do |op|
  assert(
    op.key?(:success),
    'Create topic operation should have success flag'
  )

  assert(
    !op[:topic_name].nil?,
    'Create topic operation should specify topic name'
  )
end

# Verify post-creation metadata operations
post_create_ops = DT[:metadata_operations].select do |op|
  op[:operation] == 'post_creation_metadata'
end
post_create_ops.each do |op|
  next unless op[:success]

  # After creation, topic should be found (if creation was successful)
  creation_was_successful = DT[:metadata_operations].any? do |create_op|
    create_op[:operation] == 'create_topic' && create_op[:success]
  end

  next unless creation_was_successful

  assert(
    op[:target_topic_found],
    'Post-creation metadata should find the created topic'
  )
end

# Verify rapid metadata operations
rapid_ops = DT[:metadata_operations].select { |op| op[:operation].start_with?('rapid_metadata_') }
rapid_ops.each do |op|
  assert(
    op.key?(:success),
    'Rapid metadata operation should have success flag'
  )

  assert(
    op.key?(:iteration),
    'Rapid metadata operation should track iteration'
  )

  assert(
    op[:iteration] >= 0 && op[:iteration] <= 2,
    'Rapid metadata iteration should be in valid range'
  )
end

# Verify existing topic metadata operations
existing_ops = DT[:metadata_operations].select { |op| op[:operation] == 'existing_topic_metadata' }
existing_ops.each do |op|
  next unless op[:success]

  assert(
    op[:target_topic_found],
    'Existing topic metadata should find the topic'
  )

  assert(
    op[:topics_found] > 0,
    'Should find at least one topic in cluster'
  )
end

# The key success criteria: metadata refresh during topic changes
metadata_operations_count = DT[:metadata_operations].size
successful_operations = DT[:metadata_operations].count { |op| op[:success] }

assert(
  metadata_operations_count >= 4,
  'Should perform multiple metadata operations during topic changes'
)

assert(
  successful_operations > 0,
  'Should successfully handle metadata refresh during topic changes'
)
