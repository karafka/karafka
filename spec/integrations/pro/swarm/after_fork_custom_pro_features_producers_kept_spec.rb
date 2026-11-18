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

# When the swarm.node.after_fork hook sets its own scheduled messages and recurring tasks
# producers, Karafka should not replace them with the default producer

setup_karafka do |config|
  config.swarm.nodes = 1
end

Karafka.monitor.subscribe("swarm.node.after_fork") do
  config = Karafka::App.config

  config.producer = WaterDrop::Producer.new do |producer_config|
    producer_config.kafka = Karafka::Setup::AttributesMap.producer(config.kafka.dup)
    producer_config.logger = config.logger
  end

  custom = WaterDrop::Producer.new do |producer_config|
    producer_config.kafka = Karafka::Setup::AttributesMap.producer(config.kafka.dup)
    producer_config.logger = config.logger
  end

  config.scheduled_messages.producer = custom
  config.recurring_tasks.producer = custom
end

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    config = Karafka::App.config

    WRITER.puts(
      [
        config.scheduled_messages.producer.equal?(Karafka.producer),
        config.recurring_tasks.producer.equal?(Karafka.producer),
        config.scheduled_messages.producer.equal?(config.recurring_tasks.producer)
      ].join(":")
    )
    WRITER.flush
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until(mode: :swarm) do
  DT[:result] = READER.gets&.strip

  !DT[:result].nil?
end

assert_equal "false:false:true", DT[:result]
