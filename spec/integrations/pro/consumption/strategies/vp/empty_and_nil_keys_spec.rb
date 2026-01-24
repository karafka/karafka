# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Virtual partitions should handle edge cases with empty keys, nil keys, and keys that
# result in invalid partitioning scenarios without crashing the consumer.

setup_karafka do |config|
  config.max_messages = 50
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:messages_processed] << messages.size

    messages.each do |message|
      key = message.key
      DT[:keys_received] << key
      DT[:payloads] << message.payload

      # Track which virtual partition this was processed in
      DT[:vp_ids] << Thread.current[:virtual_partition_id] if Thread.current[:virtual_partition_id]
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    deserializer ->(message) { message.raw_payload }
    virtual_partitions(
      partitioner: lambda do |msg|
        key = msg.key

        # Handle edge cases
        return 'default' if key.nil?
        return 'empty' if key.empty?
        return 'whitespace' if key.strip.empty?

        # Return consistent partitioning for valid keys
        key.hash % 5
      end
    )
  end
end

# Produce messages with edge case keys
messages_to_produce = [
  { payload: 'msg1', key: nil },
  { payload: 'msg2', key: '' },
  { payload: 'msg3', key: '   ' },
  { payload: 'msg4', key: 'valid_key' },
  { payload: 'msg5', key: nil },
  { payload: 'msg6', key: '' },
  { payload: 'msg7', key: 'another_key' }
]

messages_to_produce.each do |msg|
  if msg[:key].nil? || msg[:key].empty?
    # WaterDrop doesn't allow nil or empty keys, so we produce without key
    produce(DT.topic, msg[:payload])
  else
    produce(DT.topic, msg[:payload], key: msg[:key])
  end
end

start_karafka_and_wait_until do
  DT[:payloads].size >= messages_to_produce.size
end

# Verify all messages were processed
assert_equal messages_to_produce.size, DT[:payloads].size

# Verify edge case keys were handled properly
# Messages without keys will have nil key in Kafka
assert DT[:keys_received].count(nil) >= 3 # nil and empty keys become nil

# Verify valid keys were processed
assert DT[:keys_received].include?('   ') # whitespace key is preserved
assert DT[:keys_received].include?('valid_key')
assert DT[:keys_received].include?('another_key')

# Verify all expected payloads were received
expected_payloads = messages_to_produce.map { |msg| msg[:payload] }
assert_equal expected_payloads.sort, DT[:payloads].sort
