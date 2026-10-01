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

# Share group (KIP-932) virtual partitions with the round robin partitioner: records of a single
# topic partition are spread across several consumer instances that process them in parallel.

setup_karafka do |config|
  config.concurrency = 4
end

class Consumer < Karafka::ShareConsumer
  def consume
    started_at = Time.now.to_f
    sleep(1)

    DT[:batches] << [object_id, started_at, Time.now.to_f]

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
      virtual_partitions(partitioner: :round_robin, max_partitions: 4)
    end
  end
end

setup_share_group

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 20
end

assert_equal elements.sort, DT[:accepted].uniq.sort
assert DT[:batches].map(&:first).uniq.size >= 2

overlapping = DT[:batches].combination(2).any? do |first, second|
  first[0] != second[0] && first[1] < second[2] && second[1] < first[2]
end

assert overlapping
