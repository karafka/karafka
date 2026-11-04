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

# Share group (KIP-932) virtual partitions acknowledging synchronously: consumers of all virtual
# partitions accept their records with mark_as_accepted! concurrently and every acknowledgement is
# confirmed by the broker.

setup_karafka do |config|
  config.concurrency = 4
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:type]
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:results] << mark_as_accepted!(message)
      DT[:accepted] << message.raw_payload
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
      virtual_partitions(
        partitioner: Karafka::Pro::Processing::ShareGroups::VirtualPartitions::Partitioners::RoundRobin.new,
        max_partitions: 4
      )
    end
  end
end

setup_share_group

elements = DT.uuids(40)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:accepted].size >= 40
end

assert_equal elements.sort, DT[:accepted].sort
assert_equal [true], DT[:results].uniq
assert DT[:errors].empty?
