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

# Share group (KIP-932) dead letter queue keeps the progress made before an error: records the
# consumer acknowledged before raising are not retried nor dispatched to the DLQ, only the ones it
# did not get to are.

setup_karafka(allow_errors: %w[consumer.consume.error])

class Consumer < Karafka::ShareConsumer
  def consume
    messages.each do |message|
      DT[:deliveries] << [message.raw_payload, message.delivery_count]

      raise StandardError if message.raw_payload.start_with?("failing")

      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(topic: DT.topics[1], max_retries: 0)
    end
  end
end

setup_share_group(DT.topics[0])
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

accepted = DT.uuids(5)
produce_many(DT.topics[0], accepted + %w[failing-1 failing-2])

start_karafka_and_wait_until do
  Karafka::Admin.read_topic(DT.topics[1], 0, 10).size >= 2
end

dispatched = Karafka::Admin.read_topic(DT.topics[1], 0, 10).map(&:raw_payload)

assert_equal %w[failing-1 failing-2], dispatched.sort

# Records accepted before the error were delivered once and never dispatched
accepted.each do |payload|
  assert_equal [1], DT[:deliveries].select { |name, _| name == payload }.map(&:last)
end
