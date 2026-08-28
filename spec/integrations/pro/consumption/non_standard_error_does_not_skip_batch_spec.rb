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

# A batch whose processing raises a non-StandardError must not be silently skipped also when
# running with the Pro strategies: the failure is recorded class-agnostically, the regular
# retry flow engages and the batch is redelivered instead of the next successful batch
# committing offsets past it.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 1
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:type]
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Fail only on the first encounter so that when the batch is redelivered (expected
      # at-least-once behavior) it processes fine and the spec can complete
      if message.offset == 2 && !DT.key?(:poisoned)
        DT[:poisoned] = true

        # Descends from ScriptError, not StandardError
        raise NotImplementedError, "non-StandardError raised mid-consume"
      end

      DT[:consumed] << message.offset
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(5))

started_at = Time.now

start_karafka_and_wait_until do
  ((0..4).to_a - DT[:consumed]).empty? || (Time.now - started_at) > 30
end

assert DT[:errors].include?("consumer.consume.error"), DT[:errors]

assert(
  DT[:consumed].include?(2),
  "offset 2 was never consumed - batch silently skipped " \
  "(consumed: #{DT[:consumed].sort}, committed next offset: #{fetch_next_offset})"
)

assert_equal (0..4).to_a, DT[:consumed].uniq.sort
