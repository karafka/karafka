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

# Upon non-recoverable errors, Karafka should move forward skipping given message even if no
# marking happens for each batch.
# Since we mark the message prior to its processing (stupid but valid) we go to DLQ with the next
# one, hence the skip

class Listener
  def on_error_occurred(_event)
    DT[:errors] << true
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    group = messages.map(&:offset)
    DT[:groups] << group

    messages.each do |message|
      mark_as_consumed!(message)

      offset = message.offset

      if !DT[:errored].include?(offset) && (offset % 5) == 4 && group.last != offset
        DT[:errored] << offset

        raise StandardError
      end

      DT[0] << offset
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    long_running_job true
    dead_letter_queue topic: DT.topics[1], max_retries: 0
    manual_offset_management true
  end
end

produce_many(DT.topics[0], DT.uuids(100))

start_karafka_and_wait_until do
  DT[:errors].size >= 2 && DT[0].size >= 60
end

# We skip last errored because it will not have continuity
DT[:errored][0..-2].each do |errored_offset|
  # The way we move offset makes it such, that we consider +1 offset message as the one that failed
  # This means, that after skip to DLQ it's the +2 from which we should start
  assert(DT[:groups].any? { |group| group[0] == errored_offset + 2 })
end
