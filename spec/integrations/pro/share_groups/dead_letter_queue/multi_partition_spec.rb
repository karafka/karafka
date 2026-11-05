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

# Share group (KIP-932) dead letter queue should move failing records from all the partitions of a
# multi-partition source topic into a multi-partition DLQ topic. OSS DLQ does not preserve the
# source partition, so we only check that every record payload made it there.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:partitions] << message.partition
    end

    raise StandardError
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 0)
    end
  end
end

setup_share_group(DT.topics[0], DT.group, 10)
Karafka::Admin.create_topic(DT.topics[1], 10, 1)

elements = []

10.times do |i|
  partition_elements = DT.uuids(10)
  elements.concat(partition_elements)
  produce_many(DT.topics[0], partition_elements, partition: i)
end

def dispatched
  Array.new(10) { |i| Karafka::Admin.read_topic(DT.topics[1], i, 100) }.flatten.map(&:raw_payload)
end

start_karafka_and_wait_until(sleep: 1) do
  dispatched.size >= 100
end

assert_equal (0..9).to_a, DT[:partitions].uniq.sort
assert_equal elements.sort, dispatched.sort
