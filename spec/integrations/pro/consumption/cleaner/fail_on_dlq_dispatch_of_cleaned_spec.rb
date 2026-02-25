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

# Attempt to dispatch to DLQ a cleaned message should always fail

setup_karafka(allow_errors: true)

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event.payload[:error]
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      message.clean!

      raise if message.offset == 5

      mark_as_consumed(message)
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    dead_letter_queue(
      topic: "dead_messages",
      max_retries: 0
    )
  end
end

elements = DT.uuids(7).map { |val| { val: val }.to_json }
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:errors].size >= 2
end

# This error should be raised if DLQ dispatch attempt happens for cleaned message
assert DT[:errors].last.is_a?(Karafka::Pro::Cleaner::Errors::MessageCleanedError)
