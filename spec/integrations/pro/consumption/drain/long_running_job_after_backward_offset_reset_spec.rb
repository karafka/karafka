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

# When a topic is recreated, librdkafka resets its partitions back to the earliest offset. When
# the first messages after that reset are drained, the LRJ pause must still resume each partition
# right after its last consumed message: no message may be consumed twice and the position of a
# paused partition must match the last consumed offset.
#
# Small partition fetches keep messages of many partitions queued, so later batches are drained.

PARTITIONS = 4
BEFORE = 200
AFTER = 20

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 50
  config.concurrency = 4
end

class Consumer < Karafka::BaseConsumer
  def consume
    phase = DT.key?(:recreated) ? :after : :before
    position = fetch_position(client, topic.name, partition)

    DT[:positions] << [partition, messages.last.offset + 1, position] if phase == :after

    messages.each { |message| DT[[phase, partition]] << message.offset }
  end
end

draw_topics do
  topic DT.topic do
    partitions PARTITIONS
  end
end

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer Consumer
    long_running_job true
  end
end

PARTITIONS.times do |partition|
  produce_many(DT.topic, DT.uuids(BEFORE), partition: partition)
end

Thread.new do
  sleep(0.1) until PARTITIONS.times.all? { |partition| DT[[:before, partition]].size >= BEFORE }

  Karafka::Admin.delete_topic(DT.topic)
  Karafka::Admin.create_topic(DT.topic, PARTITIONS, 1)
  DT[:recreated] = true

  PARTITIONS.times do |partition|
    produce_many(DT.topic, DT.uuids(AFTER), partition: partition)
  end
end

start_karafka_and_wait_until do
  PARTITIONS.times.all? { |partition| DT[[:after, partition]].size >= AFTER } &&
    sleep(5)
end

PARTITIONS.times do |partition|
  assert_equal (0...BEFORE).to_a, DT[[:before, partition]]
  assert_equal (0...AFTER).to_a, DT[[:after, partition]]
end

# A seek clears the position (-1) until the next fetch, which then starts at the seek offset
DT[:positions].each do |partition, expected, position|
  assert [expected, -1].include?(position), [partition, DT[:positions]]
end
