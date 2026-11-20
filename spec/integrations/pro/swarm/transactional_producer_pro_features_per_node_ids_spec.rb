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

# When the default producer is transactional, the scheduled messages and recurring tasks
# producers in each swarm node should use the per-node transactional.id of the node producer

setup_karafka do |config|
  config.swarm.nodes = 2
end

TRANSACTIONAL_ID = SecureRandom.uuid

Karafka::App.config.producer = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  producer_config.kafka[:"transactional.id"] = TRANSACTIONAL_ID
  producer_config.logger = Karafka::App.config.logger
end

# The setup already bound the Pro features to the helper producer, so we bind them again
Karafka::App.config.scheduled_messages.producer = Karafka.producer
Karafka::App.config.recurring_tasks.producer = Karafka.producer

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    config = Karafka::App.config

    WRITER.puts(
      [
        Process.pid,
        config.scheduled_messages.producer.config.kafka[:"transactional.id"],
        config.recurring_tasks.producer.config.kafka[:"transactional.id"]
      ].join(":")
    )
    WRITER.flush
  end
end

draw_topics do
  topic DT.topic do
    partitions 2
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

producer = nil
results = {}

start_karafka_and_wait_until(mode: :swarm) do
  # Keep producing so both nodes get data (Karafka.producer is closed pre-fork)
  producer ||= WaterDrop::Producer.new do |producer_config|
    producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  end

  2.times do |partition|
    producer.produce_sync(topic: DT.topic, payload: "1", partition: partition)
  end

  while READER.wait_readable(1)
    pid, scheduled_id, recurring_id = READER.gets.strip.split(":")
    results[pid] = [scheduled_id, recurring_id]
  end

  results.size == 2
end

producer.close

assert_equal(
  [
    %W[#{TRANSACTIONAL_ID}_0 #{TRANSACTIONAL_ID}_0],
    %W[#{TRANSACTIONAL_ID}_1 #{TRANSACTIONAL_ID}_1]
  ],
  results.values.sort
)
