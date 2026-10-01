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

# Share group (KIP-932) virtual partitions with a dead letter queue: a record that keeps failing in
# one virtual partition is moved to the DLQ once it exceeds max_retries, while records of the other
# virtual partitions are accepted and never dispatched.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 2
end

class Consumer < Karafka::ShareConsumer
  def consume
    poison = false

    messages.each do |message|
      if message.raw_payload == "poison"
        poison = true
        DT[:poison] << message.delivery_count
      else
        DT[:accepted] << message.raw_payload
        mark_as_accepted(message)
      end
    end

    raise StandardError if poison
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 1)
      virtual_partitions(
        partitioner: Karafka::Pro::Processing::ShareGroups::VirtualPartitions::Partitioners::RoundRobin.new,
        max_partitions: 2
      )
    end
  end
end

setup_share_group(DT.topics[0])
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].raw_payload
end

elements = DT.uuids(10)
produce_many(DT.topics[0], elements.first(5) + ["poison"] + elements.last(5))

start_karafka_and_wait_until do
  if DT[:dispatched].size >= 1 && DT[:accepted].uniq.size >= 10
    DT[:dispatched_at] ||= Time.now

    # Make sure the broker does not deliver it again
    Time.now - DT[:dispatched_at] > 5
  else
    false
  end
end

assert_equal [1, 2], DT[:poison]
assert_equal ["poison"], DT[:dispatched]
assert_equal ["poison"], Karafka::Admin.read_topic(DT.topics[1], 0, 10).map(&:raw_payload)
assert_equal elements.sort, DT[:accepted].uniq.sort
