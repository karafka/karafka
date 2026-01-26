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

# This spec verifies that Pro DLQ strategy works correctly when external libraries monkey-patch
# the Messages#each method (e.g., for tracing/instrumentation purposes).
#
# The Pro DLQ strategy internally uses messages.raw.find to locate skippable messages,
# which bypasses the patched each method by accessing the underlying array directly.
#
# @see https://github.com/karafka/karafka/issues/2939

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 10
end

# Simulation of external Messages#each patch (like tracing libraries do)
# This tracks when #each is called to verify internal DLQ code doesn't trigger it
module ExternalEachPatchSimulationProDlq
  def each(&)
    caller_location = caller_locations(1, 10).find do |loc|
      loc.path.include?("karafka") && !loc.path.include?("spec")
    end

    DT[:each_calls] << {
      caller: caller_location&.label,
      path: caller_location&.path,
      from_dlq_strategy: caller_location&.path&.include?("strategies/dlq")
    }

    super
  end
end

# Apply the external patch simulation
Karafka::Messages::Messages.prepend(ExternalEachPatchSimulationProDlq)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.offset

      # Always raise on first message to trigger DLQ after max_retries
      raise StandardError, "Test error" if message.offset == 0
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:dlq_received] << message.offset
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 2)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

produce_many(DT.topics[0], DT.uuids(5))

start_karafka_and_wait_until do
  DT[:dlq_received].include?(0)
end

# Verify that #each was NOT called from DLQ strategy code
dlq_strategy_calls = DT[:each_calls].select { |call| call[:from_dlq_strategy] }

assert dlq_strategy_calls.empty?, <<~MSG
  Pro DLQ strategy should not trigger patched #each method.
  Found #{dlq_strategy_calls.size} calls from DLQ strategy code:
  #{dlq_strategy_calls.map { |c| "  - #{c[:caller]} at #{c[:path]}" }.join("\n")}

  This causes issues with external instrumentation libraries creating unwanted spans.
  Fix: Use messages.raw.find instead of messages.find
MSG

# Verify that #each WAS called from user code
user_calls = DT[:each_calls].reject { |call| call[:from_dlq_strategy] }
assert user_calls.any?, "User code should trigger the patched #each method"
