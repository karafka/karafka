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

# When independent flag is on and a message recovers mid-batch with sync marking, the errors
# tracker of the next failing message in the same batch should hold only its own errors

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 10
end

RecoveredError = Class.new(StandardError)
FailingError = Class.new(StandardError)

class DlqErrorStrategy
  def call(errors_tracker, attempt)
    DT[:tracked] << errors_tracker.all.map(&:class)
    DT[:counts] << errors_tracker.counts.dup

    (attempt > 2) ? :dispatch : :retry
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      raise RecoveredError if message.raw_payload == "fail-once" && attempt == 1
      raise FailingError if message.raw_payload == "always-fail"

      DT[:consumed] << message.offset

      mark_as_consumed!(message)
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:dlq] << message.raw_payload }
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(
      topic: DT.topics[1],
      max_retries: 2,
      independent: true,
      strategy: DlqErrorStrategy.new
    )
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

produce_many(DT.topic, %w[fail-once always-fail ok])

start_karafka_and_wait_until do
  DT[:consumed].include?(2) && DT.key?(:dlq)
end

assert_equal [RecoveredError], DT[:tracked][0]
assert_equal [FailingError], DT[:tracked][1]
assert_equal [FailingError, FailingError], DT[:tracked][2]
assert_equal [FailingError, FailingError, FailingError], DT[:tracked][3]
assert_equal({ FailingError => 3 }, DT[:counts].last)
assert_equal %w[always-fail], DT[:dlq]
