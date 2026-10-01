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

# Share group (KIP-932) virtual partitions with a custom partitioner: records with the same key
# always land in the same virtual partition, so they are processed by the same consumer instance.

setup_karafka do |config|
  config.concurrency = 4
end

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:keys] << [message.key, object_id]
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
      virtual_partitions(partitioner: ->(message) { message.key }, max_partitions: 4)
    end
  end
end

setup_share_group

messages = Array.new(40) { |index| { topic: DT.topic, key: "key-#{index % 8}", payload: index.to_s } }
Karafka.producer.produce_many_sync(messages)

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 40
end

DT[:keys].group_by(&:first).each_value do |pairs|
  assert_equal 1, pairs.map(&:last).uniq.size
end

assert DT[:keys].map(&:last).uniq.size >= 2
