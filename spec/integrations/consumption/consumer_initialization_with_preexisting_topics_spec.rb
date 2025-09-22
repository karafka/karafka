# frozen_string_literal: true

# Karafka should initialize consumers properly when topics already have messages

setup_karafka

class PreExistingTopicConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << {
        payload: message.raw_payload,
        offset: message.metadata.offset,
        partition: message.metadata.partition
      }
    end
  end

  def initialized
    DT[:initialized] = true
    DT[:initialized_at] = Time.now
  end
end

draw_routes(PreExistingTopicConsumer)

# Pre-populate topic with messages before starting consumer
pre_existing_messages = %w[
  pre_existing_message_1
  pre_existing_message_2
  pre_existing_message_3
]

pre_existing_messages.each { |msg| produce(DT.topic, msg) }

start_karafka_and_wait_until do
  DT[:consumed].size >= pre_existing_messages.size
end

# Verify consumer processed pre-existing messages (main test goal)
assert DT[:initialized]
assert DT[:consumed].size >= pre_existing_messages.size

# Verify pre-existing messages were consumed
assert_equal pre_existing_messages.size, DT[:consumed].size

# Verify messages were consumed in order with correct offsets
consumed_payloads = DT[:consumed].map { |msg| msg[:payload] }
assert_equal pre_existing_messages, consumed_payloads

# Verify offsets are sequential starting from 0
offsets = DT[:consumed].map { |msg| msg[:offset] }.sort
expected_offsets = (0...pre_existing_messages.size).to_a
assert_equal expected_offsets, offsets

# All messages should be from the same partition
partitions = DT[:consumed].map { |msg| msg[:partition] }.uniq
assert_equal 1, partitions.size
assert_equal 0, partitions.first
