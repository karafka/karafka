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

# DLQ in the VP mode should collapse and skip when error occurs again in a collapsed mode
# After that, we should move to processing in a non-collapsed mode again

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 100
end

MUTEX = Mutex.new

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Simulates a broken message that for example one that cannot be deserialized
      raise StandardError if message.offset == 5

      # Mark only in a collapsed mode
      mark_as_consumed(message) if collapsed?

      DT[:flow] << [message.offset, object_id, collapsed?]
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:dlq] << message
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
    virtual_partitions(
      partitioner: ->(message) { message.raw_payload }
    )
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 1
    )
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

produce_many(DT.topic, (0..9).to_a.map(&:to_s))

start_karafka_and_wait_until do
  if !DT[:dlq].empty? && !DT[:flow].include?([:post_dlq])
    sleep(5)
    DT[:flow] << [:post_dlq]
    produce_many(DT.topic, (10..19).to_a.map(&:to_s))
  end

  DT[:flow].size >= 20
end

# We should not have in our data message with offset 5 as it failed
assert(DT[:flow].none? { |row| row.first == 5 })

# It should be moved to DLQ
assert_equal 5, DT[:dlq].first.headers['source_offset'].to_i

# One message should be moved
assert_equal 1, DT[:dlq].size

# After we got back to running VPs, all should run in VP
uncollapsed_index = DT[:flow].index { |row| row == [:post_dlq] }
uncollapsed = DT[:flow][(uncollapsed_index + 1)..100]

# All post-collapse should not be collapsed
assert uncollapsed.none?(&:last)

# Post collapse should run in multiple threads
assert uncollapsed.map { |row| row[1] }.uniq.size >= 2
