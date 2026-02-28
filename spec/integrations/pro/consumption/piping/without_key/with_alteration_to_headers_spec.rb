# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# We should be able to define extra method that we can use to alter headers

setup_karafka

class Consumer1 < Karafka::BaseConsumer
  def consume
    messages.each_with_index do |message, index|
      if (index % 2).zero?
        pipe_async(topic: DT.topics[1], message: message)
      else
        pipe_sync(topic: DT.topics[1], message: message)
      end
    end
  end

  private

  def enhance_pipe_message(pipe_message_hash, message)
    pipe_message_hash[:headers]["extra_data"] = "1"
    pipe_message_hash[:headers]["extra_test"] = message.raw_payload
  end
end

class Consumer2 < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:piped] << message
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topics[0] do
      config(partitions: 2)
      consumer Consumer1
    end
  end

  topic DT.topics[1] do
    consumer Consumer2
  end
end

P1 = DT.uuids(50)
P2 = DT.uuids(50)

SETS = [P1, P2].freeze

2.times do |i|
  produce_many(DT.topic, SETS[i], partition: i)
end

start_karafka_and_wait_until do
  DT[:piped].size >= 100
end

EXPECTED_PARTITIONS = [0, 1].freeze
EXPECTED_KEYS = %w[0 1].freeze

DT[:piped].each do |message|
  headers = message.headers

  source_partition = headers["source_partition"].to_i

  assert SETS[source_partition].include?(message.raw_payload)
  assert EXPECTED_PARTITIONS.include?(source_partition)
  assert EXPECTED_KEYS.include?(message.key)
  assert_equal headers["source_topic"], DT.topics.first
  assert_equal headers["source_topic"], DT.topics.first
  assert_equal "1", headers["extra_data"]
  assert_equal message.raw_payload, headers["extra_test"]
end
