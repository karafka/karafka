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

# Share group (KIP-932) dead letter queue with `topic: false`: a record that keeps failing is
# rejected once it was delivered more than `max_retries` times, without dispatching it anywhere.
# It is not delivered again and the rest of the topic is consumed.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    poison = false

    messages.each do |message|
      if message.raw_payload == "poison"
        poison = true
        DT[:poison] << message.delivery_count
      else
        DT[:accepted] << message.raw_payload
        mark_as_accepted(message)
      end
    end

    raise StandardError if poison
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      consumer Consumer
      dead_letter_queue(topic: false, max_retries: 1)
    end
  end
end

setup_share_group

Karafka.monitor.subscribe("dead_letter_queue.dispatched") do |event|
  DT[:dispatched] << event[:message].raw_payload
end

elements = DT.uuids(10)
produce_many(DT.topic, elements.first(5) + ["poison"] + elements.last(5))

start_karafka_and_wait_until do
  if DT[:poison].size >= 2 && DT[:accepted].uniq.size >= 10
    DT[:rejected_at] = Time.now unless DT.key?(:rejected_at)

    # Make sure the broker does not deliver it again
    Time.now - DT[:rejected_at] > 5
  else
    false
  end
end

assert_equal [1, 2], DT[:poison]
assert_equal [], DT[:dispatched]
assert_equal elements.sort, DT[:accepted].uniq.sort
