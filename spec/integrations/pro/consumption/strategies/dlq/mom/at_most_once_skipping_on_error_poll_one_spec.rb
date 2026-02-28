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

# This example is a bit counter intuitive. Since we mark as consumed before we consume and raise
# error, Karafka will skip this message and move on. On another it will again encounter error
# and will dispatch to DLQ the next message because Karafka does not know, that marking happened
# prior to an error. This is however expected. If you want to alter this behaviour, you need to
# write your own custom strategy to compensate for this by moving the seek offset back for a DLQ
# dispatch case.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::BaseConsumer
  def consume
    mark_as_consumed messages.first

    DT[0] << messages.first.offset

    raise StandardError
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << message.headers["source_offset"].to_i
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    max_messages 1
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 1)
    manual_offset_management true
  end

  topic DT.topics[1] do
    consumer DlqConsumer
    manual_offset_management true
  end
end

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 20 && DT[:broken].size >= 10
end

assert_equal (DT[0] + DT[:broken]).sort.uniq, (0..19).to_a
assert_equal [1, 3, 5, 7, 9, 11, 13, 15, 17, 19], DT[:broken]
