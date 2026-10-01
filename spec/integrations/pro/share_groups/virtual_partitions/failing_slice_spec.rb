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

# Share group (KIP-932) virtual partitions isolate failures: when one virtual partition fails, only
# its records are released and redelivered. Records processed by the other virtual partitions of
# the same batch are accepted and never delivered again.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 2
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each { |message| DT[:deliveries] << [message.raw_payload, message.delivery_count] }

    failing = messages.any? do |message|
      message.raw_payload == "failing" && message.delivery_count == 1
    end

    raise StandardError if failing

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
      virtual_partitions(partitioner: :round_robin, max_partitions: 2)
    end
  end
end

setup_share_group

others = DT.uuids(9)
produce_many(DT.topic, ["failing"] + others)

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 10
end

deliveries = DT[:deliveries].group_by(&:first).transform_values { |pairs| pairs.map(&:last) }

assert_equal 2, deliveries.fetch("failing").max

# Some records were in the healthy virtual partition and were delivered only once
assert(deliveries.values.count { |counts| counts == [1] } >= 1)
assert_equal (["failing"] + others).sort, DT[:accepted].uniq.sort
