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

# Share group (KIP-932) dead letter queue should dispatch with the consumer custom producer when
# `#producer` is redefined, even if the default producer does not work.

setup_karafka(allow_errors: %w[consumer.consume.error])

SUPER_PRODUCER = WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
end

class Consumer < Karafka::ShareConsumer
  def consume
    poison = false

    messages.each do |message|
      if message.raw_payload == "poison"
        poison = true
      else
        DT[:accepted] << message.raw_payload
        mark_as_accepted(message)
      end
    end

    raise StandardError if poison
  end

  def producer
    SUPER_PRODUCER
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(
        topic: DT.topics[1],
        max_retries: 2,
        dispatch_method: :produce_sync
      )
    end
  end
end

setup_share_group(DT.topics[0])
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

elements = DT.uuids(4)
produce_many(DT.topics[0], ["poison"] + elements)

# We set it to something that is not working (not this cluster)
Karafka::App.config.producer = WaterDrop::Producer.new do |config|
  config.deliver = true
  config.kafka = {
    "bootstrap.servers": "localhost:999",
    "message.timeout.ms": 1_000
  }
end

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 4 &&
    Karafka::Admin.read_topic(DT.topics[1], 0, 10).size >= 1
end

assert_equal elements.sort, DT[:accepted].uniq.sort
assert_equal ["poison"], Karafka::Admin.read_topic(DT.topics[1], 0, 10).map(&:raw_payload)

SUPER_PRODUCER.close
