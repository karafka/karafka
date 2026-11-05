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

# Share group (KIP-932) dead letter queues can be chained into a pipeline where each stage is a
# share topic with its own DLQ: a record failing on every stage moves through all of them and
# lands in the last topic exactly once.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:attempts] << [topic.name, message.delivery_count]
    end

    raise StandardError
  end
end

class LastConsumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:broken] << [message.offset, message.raw_payload]
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    4.times do |i|
      topic DT.topics[i] do
        consumer Consumer
        dead_letter_queue(topic: DT.topics[i + 1], max_retries: 1)
      end
    end

    topic DT.topics[4] do
      consumer LastConsumer
    end
  end
end

5.times { |i| setup_share_group(DT.topics[i]) }

elements = DT.uuids(1)
produce_many(DT.topics[0], elements)

start_karafka_and_wait_until do
  DT.key?(:broken) && sleep(2)
end

assert_equal 1, DT[:broken].size
# This message gets a new offset (first) in the last topic
assert_equal 0, DT[:broken][0][0]
assert_equal elements[0], DT[:broken][0][1]

# Every stage got the record twice (first delivery and one retry) before moving it on
4.times do |i|
  assert_equal [1, 2], DT[:attempts].select { |name, _| name == DT.topics[i] }.map(&:last)
end
