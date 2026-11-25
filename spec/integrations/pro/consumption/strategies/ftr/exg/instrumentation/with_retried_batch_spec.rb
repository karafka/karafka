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

# When a batch with expired messages fails and is fetched again, Karafka should report its expired
# messages again, because each filtering run reports what it removed

setup_karafka(allow_errors: %w[consumer.consume.error])

Karafka.monitor.subscribe("rebalance.partitions_assigned") do
  DT[:assigned] = true
end

Karafka.monitor.subscribe("filtering.expired") do |event|
  DT[:expired] << event.payload.values_at(:first_offset, :last_offset, :count)
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:raised)
      DT[:raised] = true
      raise StandardError
    end

    messages.each { |message| DT[:consumed] << message.offset }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    # 1 minute
    expire_in(60_000)
  end
end

old_timestamp = ((Time.now.to_f * 1_000).to_i - 600_000)

start_karafka_and_wait_until do
  if DT.key?(:assigned) && !DT.key?(:produced)
    DT[:produced] = true

    # One sync dispatch so all of them land in one batch: 5 old and then 5 fresh messages
    Karafka.producer.produce_many_sync(
      DT.uuids(5).map { |payload| { topic: DT.topic, payload: payload, timestamp: old_timestamp } } +
        DT.uuids(5).map { |payload| { topic: DT.topic, payload: payload } }
    )
  end

  DT[:consumed].size >= 5
end

assert_equal (5..9).to_a, DT[:consumed]
# Fetches may split the batch, so we check how many times each expired offset was reported
reported = DT[:expired].flat_map { |first, last, _count| (first..last).to_a }.tally

assert_equal({ 0 => 2, 1 => 2, 2 => 2, 3 => 2, 4 => 2 }, reported.sort.to_h)
assert_equal 10, DT[:expired].sum(&:last)
