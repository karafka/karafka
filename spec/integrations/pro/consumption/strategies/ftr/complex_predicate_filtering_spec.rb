# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Filtering should handle complex predicates including JSON parsing, regex matching,
# timestamp-based filtering, and composite conditions without performance degradation.

setup_karafka do |config|
  config.max_messages = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:processed_messages] << messages.size

    messages.each do |message|
      data = JSON.parse(message.raw_payload)
      DT[:processed_data] << data
      DT[:processed_offsets] << message.offset
    end
  end
end

# Complex filter that combines multiple predicates
class ComplexPredicateFilter < Karafka::Pro::Processing::Filters::Base
  attr_reader :cursor

  def apply!(messages)
    @applied = false
    @cursor = nil

    # Filter messages based on complex predicates
    messages.delete_if do |message|
      data = JSON.parse(message.raw_payload)

      # Complex filtering logic
      should_filter = false

      # Filter 1: Skip messages with invalid user_id format
      should_filter = true if data['user_id'] && !data['user_id'].match?(/^user_\d+$/)

      # Filter 2: Skip messages older than 1 hour (simulated)
      should_filter = true if data['timestamp'] && data['timestamp'] < (Time.now.to_i - 3600)

      # Filter 3: Skip messages with sensitive data
      should_filter = true if data['type'] == 'sensitive'

      # Filter 4: Skip messages from blocked domains
      should_filter = true if data['email'] && data['email'].end_with?('@blocked.com')

      # Filter 5: Complex business logic - skip incomplete orders
      should_filter = true if data['type'] == 'order' && (!data['items'] || data['items'].empty?)

      should_filter
    rescue JSON::ParserError
      # Skip messages that are not valid JSON
      true
    end

    @applied = messages.size < 20
  end

  def action
    :skip
  end

  def applied?
    @applied
  end

  def timeout
    0
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    deserializer ->(message) { message.raw_payload }
    filter(->(*) { ComplexPredicateFilter.new })
  end
end

# Produce messages with various filtering scenarios
test_messages = [
  # Valid messages that should pass
  { user_id: 'user_123', timestamp: Time.now.to_i, type: 'login', email: 'user@example.com' },
  { user_id: 'user_456', timestamp: Time.now.to_i, type: 'order', items: %w[item1 item2] },
  { user_id: 'user_789', timestamp: Time.now.to_i, type: 'notification' },

  # Messages that should be filtered
  { user_id: 'invalid_id', timestamp: Time.now.to_i, type: 'login' }, # Invalid user_id format
  { user_id: 'user_111', timestamp: Time.now.to_i - 7200, type: 'old_event' }, # Too old
  { user_id: 'user_222', timestamp: Time.now.to_i, type: 'sensitive' }, # Sensitive type
  { user_id: 'user_333', timestamp: Time.now.to_i, email: 'bad@blocked.com' }, # Blocked domain
  { user_id: 'user_444', timestamp: Time.now.to_i, type: 'order', items: [] }, # Empty order

  # More valid messages
  { user_id: 'user_555', timestamp: Time.now.to_i, type: 'purchase', amount: 99.99 },
  { user_id: 'user_666', timestamp: Time.now.to_i, type: 'order', items: ['special_item'] }
]

# Also produce some invalid JSON to test JSON parsing filter
invalid_json_messages = [
  'invalid json',
  '{ incomplete json',
  'not json at all'
]

# Produce all test messages
test_messages.each do |msg|
  produce(DT.topic, msg.to_json)
end

invalid_json_messages.each do |msg|
  produce(DT.topic, msg)
end

start_karafka_and_wait_until do
  DT[:processed_data].size >= 5
end

# Verify only valid messages were processed
valid_message_count = test_messages.count do |msg|
  # Simulate the same filtering logic to count expected valid messages
  next false if msg[:user_id] && !msg[:user_id].match?(/^user_\d+$/)
  next false if msg[:timestamp] && msg[:timestamp] < (Time.now.to_i - 3600)
  next false if msg[:type] == 'sensitive'
  next false if msg[:email] && msg[:email].end_with?('@blocked.com')
  next false if msg[:type] == 'order' && (!msg[:items] || msg[:items].empty?)

  true
end

assert_equal valid_message_count, DT[:processed_data].size

# Verify specific filtering behaviors
processed_user_ids = DT[:processed_data].map { |data| data['user_id'] }.compact
invalid_user_ids = processed_user_ids.reject { |id| id.match?(/^user_\d+$/) }
assert_equal [], invalid_user_ids

# Verify no sensitive data was processed
sensitive_messages = DT[:processed_data].select { |data| data['type'] == 'sensitive' }
assert_equal [], sensitive_messages

# Verify no blocked emails were processed
blocked_emails = DT[:processed_data].select { |data| data['email']&.end_with?('@blocked.com') }
assert_equal [], blocked_emails

# Verify no empty orders were processed
empty_orders = DT[:processed_data].select do |data|
  data['type'] == 'order' && (!data['items'] || data['items'].empty?)
end
assert_equal [], empty_orders
