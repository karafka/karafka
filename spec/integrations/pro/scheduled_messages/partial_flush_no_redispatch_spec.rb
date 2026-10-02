# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# When a multi-chunk flush fails on a later chunk, the earlier chunks that were already confirmed
# delivered must NOT be re-dispatched on the next tick (a duplicate window for non-transactional
# producers). We force one message per flush chunk and crash the producer at the very start of the
# second chunk (message 1's target), so the first chunk (message 0) is fully confirmed while the
# second chunk delivers nothing. Message 0 must then be delivered exactly once.

setup_karafka(allow_errors: %w[consumer.consume.error consumer.tick.error])

# target + tombstone per message => one scheduled message per flush chunk
Karafka::App.config.scheduled_messages.flush_batch_size = 2

class TrackConsumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:keys] << message.key }
  end
end

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    consumer TrackConsumer
  end
end

proxies = Array.new(3) do |i|
  message = {
    topic: DT.topics[1],
    key: i.to_s,
    payload: "payload"
  }

  Karafka::Pro::ScheduledMessages.schedule(
    message: message,
    # All due at once, so a single tick dispatches them together across multiple chunks
    epoch: Time.now.to_i,
    envelope: { topic: DT.topics[0], partition: 0 }
  )
end

Karafka.producer.produce_many_sync(proxies)

# Crash once, on message 1's target dispatch. With one message per chunk that is the first entry
# of the second chunk, so the first chunk (message 0) is already confirmed and the second chunk
# fails before delivering anything.
class Crasher
  def call(message)
    if message[:key] == "1" && !DT.key?(:crashed)
      DT[:crashed] = true
      raise
    end

    message
  end
end

Karafka.producer.middleware.append(Crasher.new)

start_karafka_and_wait_until(sleep: 1) do
  DT[:keys].uniq.size >= 3
end

# Every scheduled message delivered exactly once: the confirmed first chunk is not re-dispatched
# when the later chunk fails (on master, message 0 would be delivered twice)
assert_equal %w[0 1 2], DT[:keys].sort
assert_equal 1, DT[:keys].count("0")
