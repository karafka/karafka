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
# marking happens. When operating on batches and no marking happens, we skip first message from
# the batch on which the error happened.

FAILING_OFFSETS = [1, 25].freeze

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
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
    messages.each do |message|
      if FAILING_OFFSETS.include?(message.offset)
        DT[:firsts] << messages.first.offset

        raise StandardError
      end

      DT[0] << message.offset
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

produce_many(DT.topics[0], DT.uuids(50))

start_karafka_and_wait_until do
  DT[:errors].size >= 2 && DT[0].size >= 48
end

duplicates = DT[:firsts] - [1, 25]

# Failing messages should not be there
assert !DT[0].include?(1)
assert !DT[0].include?(25)

# Failing messages that are not first in batch should cause some reprocessing
duplicates.each do |duplicate|
  next if FAILING_OFFSETS.include?(duplicate + 1)

  assert DT[0].count { |nr| nr == (duplicate + 1) } > 1
end
